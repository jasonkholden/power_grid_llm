#!/bin/bash
# Power Grid LLM - Build and Deploy Script
# Usage: ./build-and-push.sh [all|build|push|upload|restart]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load configuration from terraform outputs
cd "$SCRIPT_DIR/terraform"
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id 2>/dev/null)
ECR_FRONTEND=$(terraform output -raw ecr_frontend_url 2>/dev/null)
ECR_BACKEND=$(terraform output -raw ecr_backend_url 2>/dev/null)
ECR_MCP_SERVER=$(terraform output -raw ecr_mcp_server_url 2>/dev/null)
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null)
DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null)
cd "$PROJECT_DIR"

# SSH key path
SSH_KEY="${SSH_KEY:-$HOME/.ssh/pgl-ec2}"

# MCP Server repo location (separate project)
MCP_SERVER_DIR="${MCP_SERVER_DIR:-$PROJECT_DIR/../ne_power_grid_mcp_server}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    log_info "Checking prerequisites..."

    if [ -z "$AWS_ACCOUNT_ID" ]; then
        log_error "Could not get AWS account ID from terraform. Run 'terraform apply' first."
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi

    log_info "Prerequisites OK"
}

ecr_login() {
    log_info "Logging into ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
}

build_images() {
    log_info "Building Docker images..."

    # Build backend
    log_info "Building backend image..."
    docker build -t pgl-backend:latest \
        -f "$PROJECT_DIR/backend/Dockerfile" \
        --target runtime \
        "$PROJECT_DIR/backend"

    # Build frontend (production stage)
    log_info "Building frontend image..."
    docker build -t pgl-frontend:latest \
        -f "$PROJECT_DIR/frontend/Dockerfile" \
        --target production \
        "$PROJECT_DIR/frontend"

    log_info "Docker images built successfully"
}

build_mcp_server() {
    log_info "Building MCP server Docker image..."

    if [ ! -d "$MCP_SERVER_DIR" ]; then
        log_error "MCP server directory not found: $MCP_SERVER_DIR"
        log_error "Set MCP_SERVER_DIR env var or clone ne_power_grid_mcp_server alongside this repo"
        exit 1
    fi

    docker build -t pgl-mcp-server:latest "$MCP_SERVER_DIR"

    log_info "MCP server image built successfully"
}

push_mcp_server() {
    log_info "Pushing MCP server image to ECR..."

    ecr_login

    docker tag pgl-mcp-server:latest "$ECR_MCP_SERVER:latest"
    docker push "$ECR_MCP_SERVER:latest"

    log_info "MCP server image pushed to ECR"
}

push_images() {
    log_info "Pushing images to ECR..."

    ecr_login

    # Tag and push backend
    log_info "Pushing backend image..."
    docker tag pgl-backend:latest "$ECR_BACKEND:latest"
    docker push "$ECR_BACKEND:latest"

    # Tag and push frontend
    log_info "Pushing frontend image..."
    docker tag pgl-frontend:latest "$ECR_FRONTEND:latest"
    docker push "$ECR_FRONTEND:latest"

    log_info "Images pushed to ECR successfully"
}

upload_configs() {
    log_info "Uploading configuration files to S3..."

    # Process nginx.conf template (replace domain name)
    sed "s/\${DOMAIN_NAME}/$DOMAIN_NAME/g" "$SCRIPT_DIR/nginx.conf" > /tmp/nginx.conf

    # Upload configs
    aws s3 cp "$SCRIPT_DIR/docker-compose.prod.yml" "s3://$S3_BUCKET/config/docker-compose.prod.yml" --region "$AWS_REGION"
    aws s3 cp /tmp/nginx.conf "s3://$S3_BUCKET/config/nginx.conf" --region "$AWS_REGION"

    rm /tmp/nginx.conf

    log_info "Configuration files uploaded to S3"
}

restart_containers() {
    log_info "Restarting containers on EC2 via SSH..."

    if [ ! -f "$SSH_KEY" ]; then
        log_error "SSH key not found: $SSH_KEY"
        log_error "Set SSH_KEY env var or ensure ~/.ssh/pgl-ec2 exists"
        exit 1
    fi

    # SSH command prefix
    SSH_CMD="ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP"

    # Download latest configs from S3
    log_info "Downloading configs from S3..."
    $SSH_CMD "cd /opt/pgl && sudo aws s3 cp s3://$S3_BUCKET/config/docker-compose.prod.yml docker-compose.prod.yml --region $AWS_REGION"
    $SSH_CMD "cd /opt/pgl && sudo aws s3 cp s3://$S3_BUCKET/config/nginx.conf nginx/nginx.conf --region $AWS_REGION"

    # Login to ECR
    log_info "Logging into ECR on EC2..."
    $SSH_CMD "aws ecr get-login-password --region $AWS_REGION | sudo docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

    # Pull latest images
    log_info "Pulling latest images..."
    $SSH_CMD "sudo docker pull $ECR_BACKEND:latest"
    $SSH_CMD "sudo docker pull $ECR_FRONTEND:latest"
    $SSH_CMD "sudo docker pull $ECR_MCP_SERVER:latest"

    # Stop and remove all pgl containers (workaround for docker-compose 1.29.2 bug)
    log_info "Stopping and removing containers..."
    $SSH_CMD "sudo docker ps -a --filter 'name=pgl' -q | xargs -r sudo docker rm -f 2>/dev/null || true"

    # Recreate containers
    log_info "Starting containers..."
    $SSH_CMD "cd /opt/pgl && sudo docker-compose -f docker-compose.prod.yml --env-file .env up -d"

    # Show status
    log_info "Container status:"
    $SSH_CMD "sudo docker ps"

    log_info "Containers restarted successfully"
}

show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  all        - Build, push, upload configs, and restart (full deployment)"
    echo "  build      - Build Docker images locally (frontend + backend)"
    echo "  push       - Push images to ECR (frontend + backend)"
    echo "  upload     - Upload config files to S3"
    echo "  restart    - Restart containers on EC2"
    echo "  mcp-build  - Build MCP server Docker image (from ne_power_grid_mcp_server)"
    echo "  mcp-push   - Push MCP server image to ECR"
    echo "  mcp-all    - Build and push MCP server image"
    echo ""
    echo "Examples:"
    echo "  $0 all         # Full deployment (frontend + backend)"
    echo "  $0 build       # Just build images"
    echo "  $0 restart     # Just restart containers with current images"
    echo "  $0 mcp-all     # Build and push MCP server"
    echo ""
    echo "Environment variables:"
    echo "  MCP_SERVER_DIR  - Path to ne_power_grid_mcp_server repo (default: ../ne_power_grid_mcp_server)"
}

# Main
case "${1:-all}" in
    all)
        check_prerequisites
        build_images
        push_images
        upload_configs
        restart_containers
        log_info "Full deployment complete!"
        log_info "Visit https://$DOMAIN_NAME to see your app"
        ;;
    build)
        build_images
        ;;
    push)
        check_prerequisites
        push_images
        ;;
    upload)
        check_prerequisites
        upload_configs
        ;;
    restart)
        check_prerequisites
        restart_containers
        ;;
    mcp-build)
        build_mcp_server
        ;;
    mcp-push)
        check_prerequisites
        push_mcp_server
        ;;
    mcp-all)
        check_prerequisites
        build_mcp_server
        push_mcp_server
        log_info "MCP server deployment complete!"
        log_info "Run '$0 restart' to update the running containers"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
