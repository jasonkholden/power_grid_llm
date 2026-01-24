#!/bin/bash
# Power Grid LLM - EC2 User Data Script
# This script runs on first boot to configure the instance

set -e

# Variables injected by Terraform
PROJECT_NAME="${PROJECT_NAME}"
ENVIRONMENT="${ENVIRONMENT}"
AWS_REGION="${AWS_REGION}"
DOMAIN_NAME="${DOMAIN_NAME}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL}"
EFS_ID="${EFS_ID}"
S3_BUCKET="${S3_BUCKET}"
ECR_FRONTEND="${ECR_FRONTEND}"
ECR_BACKEND="${ECR_BACKEND}"
HTTP_AUTH_LINE="${HTTP_AUTH_LINE}"
CLAUDE_API_KEY_PARAM="${CLAUDE_API_KEY_PARAM}"
APP_DIR="${APP_DIR}"
LOG_FILE="/var/log/user-data.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting Power Grid LLM instance setup..."

# Update system and install dependencies
log "Installing system dependencies..."
apt-get update
apt-get install -y \
    docker.io \
    docker-compose \
    nfs-common \
    certbot \
    python3-certbot-dns-route53 \
    jq \
    unzip \
    curl

# Install AWS CLI v2 (not available in Ubuntu 24.04 repos)
log "Installing AWS CLI v2..."
curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# Start and enable Docker
log "Starting Docker..."
systemctl start docker
systemctl enable docker

# Create application directory
log "Creating application directories..."
mkdir -p "$APP_DIR/data"
mkdir -p "$APP_DIR/nginx"

# Mount EFS
log "Mounting EFS filesystem..."
echo "$EFS_ID.efs.$AWS_REGION.amazonaws.com:/ $APP_DIR/data nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab
mount -a

# Create HTTP Basic Auth file
log "Creating HTTP auth file..."
echo '$HTTP_AUTH_LINE' > "$APP_DIR/nginx/.htpasswd"
chmod 644 "$APP_DIR/nginx/.htpasswd"

# Handle SSL certificates
log "Setting up SSL certificates..."
CERT_PATH="/etc/letsencrypt/live/$DOMAIN_NAME"

# Check if certificate exists in S3
if aws s3 ls "s3://$S3_BUCKET/ssl/" --region "$AWS_REGION" 2>/dev/null | grep -q "letsencrypt.tar.gz"; then
    log "Found existing SSL certificates in S3, restoring..."
    aws s3 cp "s3://$S3_BUCKET/ssl/letsencrypt.tar.gz" /tmp/letsencrypt.tar.gz --region "$AWS_REGION"
    tar -xzf /tmp/letsencrypt.tar.gz -C /etc/
    rm /tmp/letsencrypt.tar.gz

    # Check if certificate is valid (more than 30 days remaining)
    if openssl x509 -checkend 2592000 -noout -in "$CERT_PATH/cert.pem" 2>/dev/null; then
        log "Restored certificate is valid"
    else
        log "Restored certificate is expiring soon, will renew"
        certbot renew --non-interactive
    fi
else
    log "No existing certificates found, obtaining new ones..."
    certbot certonly \
        --dns-route53 \
        --non-interactive \
        --agree-tos \
        --email "$LETSENCRYPT_EMAIL" \
        -d "$DOMAIN_NAME" \
        -d "www.$DOMAIN_NAME"
fi

# Create certificate renewal hook to backup to S3
log "Setting up certificate renewal hooks..."
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/backup-to-s3.sh << 'HOOK'
#!/bin/bash
tar -czf /tmp/letsencrypt.tar.gz -C /etc letsencrypt
aws s3 cp /tmp/letsencrypt.tar.gz "s3://${S3_BUCKET}/ssl/letsencrypt.tar.gz" --region "${AWS_REGION}"
rm /tmp/letsencrypt.tar.gz
docker compose -f ${APP_DIR}/docker-compose.prod.yml restart frontend || true
HOOK
chmod +x /etc/letsencrypt/renewal-hooks/deploy/backup-to-s3.sh

# Enable certbot timer for auto-renewal
systemctl enable certbot.timer
systemctl start certbot.timer

# Backup current certificates to S3
log "Backing up certificates to S3..."
tar -czf /tmp/letsencrypt.tar.gz -C /etc letsencrypt
aws s3 cp /tmp/letsencrypt.tar.gz "s3://$S3_BUCKET/ssl/letsencrypt.tar.gz" --region "$AWS_REGION"
rm /tmp/letsencrypt.tar.gz

# Download configs from S3
log "Downloading configuration files from S3..."
aws s3 cp "s3://$S3_BUCKET/config/docker-compose.prod.yml" "$APP_DIR/docker-compose.prod.yml" --region "$AWS_REGION" || true
aws s3 cp "s3://$S3_BUCKET/config/nginx.conf" "$APP_DIR/nginx/nginx.conf" --region "$AWS_REGION" || true

# Fetch secrets from SSM Parameter Store
log "Fetching secrets from SSM..."
CLAUDE_API_KEY=$(aws ssm get-parameter --name "$CLAUDE_API_KEY_PARAM" --with-decryption --region "$AWS_REGION" --query 'Parameter.Value' --output text)

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

# Create environment file
log "Creating environment file..."
cat > "$APP_DIR/.env" << EOF
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
AWS_REGION=$AWS_REGION
DOMAIN_NAME=$DOMAIN_NAME
CLAUDE_API_KEY=$CLAUDE_API_KEY
ENVIRONMENT=$ENVIRONMENT
EOF
chmod 600 "$APP_DIR/.env"

# Login to ECR
log "Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Pull Docker images (one at a time to avoid OOM on small instances)
log "Pulling Docker images..."
docker pull "$ECR_BACKEND:latest" || log "Backend image not yet available"
docker pull "$ECR_FRONTEND:latest" || log "Frontend image not yet available"

# Start containers (if docker-compose.prod.yml exists)
if [ -f "$APP_DIR/docker-compose.prod.yml" ]; then
    log "Starting containers..."
    cd "$APP_DIR"
    docker compose -f docker-compose.prod.yml --env-file .env up -d
else
    log "docker-compose.prod.yml not found in S3, waiting for first deployment..."
fi

# Create systemd service for auto-start on reboot
log "Creating systemd service..."
cat > /etc/systemd/system/pgl-app.service << EOF
[Unit]
Description=Power Grid LLM Application
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/docker compose -f docker-compose.prod.yml --env-file .env up -d
ExecStop=/usr/bin/docker compose -f docker-compose.prod.yml down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pgl-app.service

log "Power Grid LLM instance setup complete!"
