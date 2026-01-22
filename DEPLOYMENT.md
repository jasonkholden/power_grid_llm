# Power Grid LLM - Deployment Guide

This document describes how to deploy the Power Grid LLM application to AWS.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                               │
│  ┌─────────────┐    ┌──────────────────────────────────────┐    │
│  │  Route53    │    │           EC2 (t4g.nano)             │    │
│  │  DNS        │───▶│  ┌─────────┐     ┌─────────┐         │    │
│  └─────────────┘    │  │Frontend │────▶│ Backend │         │    │
│                     │  │(nginx)  │     │(FastAPI)│         │    │
│  ┌─────────────┐    │  └────┬────┘     └────┬────┘         │    │
│  │    ECR      │    │       │               │              │    │
│  │  (Images)   │───▶│       │               │              │    │
│  └─────────────┘    │       ▼               ▼              │    │
│                     │  ┌─────────────────────────┐         │    │
│  ┌─────────────┐    │  │     EFS (Database)      │         │    │
│  │    S3       │    │  └─────────────────────────┘         │    │
│  │  (Configs)  │───▶│                                      │    │
│  └─────────────┘    └──────────────────────────────────────┘    │
│                                                                 │
│  ┌─────────────┐                                                │
│  │    SSM      │  (Secrets: Claude API Key)                     │
│  │ Parameters  │                                                │
│  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

1. **AWS CLI** installed and configured
2. **Terraform** >= 1.0 installed
3. **Docker** installed locally
4. **Domain name** with Route53 hosted zone

---

## Initial Setup (One-Time)

### 1. Create Terraform State Backend

Before running terraform, you need to create the S3 bucket and DynamoDB table for state storage:

```bash
# Create S3 bucket for terraform state
aws s3 mb s3://pgl-terraform-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket pgl-terraform-state \
    --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name pgl-terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

### 2. Configure Terraform Variables

```bash
cd deploy/terraform

# Edit non-secret variables
vim terraform.tfvars
# Update: domain_name, letsencrypt_email, home_ip

# Create secret variables file
cp terraform.tfvars.secret.example terraform.tfvars.secret
vim terraform.tfvars.secret
# Add: claude_api_key, http_auth_line
```

**Get your home IP:**
```bash
curl ifconfig.me
```

**Generate HTTP auth line:**
```bash
htpasswd -n admin
# Or: echo "admin:$(openssl passwd -apr1 'your-password')"
```

### 3. Initialize and Apply Terraform

```bash
cd deploy/terraform

# Initialize terraform
terraform init

# Preview changes
terraform plan

# Apply infrastructure
terraform apply
```

### 4. First Deployment

After terraform creates the infrastructure:

```bash
cd deploy
./build-and-push.sh all
```

This will:
1. Build Docker images locally
2. Push to ECR
3. Upload configs to S3
4. Restart containers on EC2

---

## Daily Operations

### Local Development

```bash
# Start local environment
docker-compose up --build

# Visit http://localhost:3001 (frontend)
# Visit http://localhost:8001/api/health (backend)

# Stop
docker-compose down
```

### Deploy Changes

```bash
# Full deployment
./deploy/build-and-push.sh all

# Or step by step:
./deploy/build-and-push.sh build    # Build images
./deploy/build-and-push.sh push     # Push to ECR
./deploy/build-and-push.sh upload   # Upload configs
./deploy/build-and-push.sh restart  # Restart containers
```

### Access EC2 (SSH via SSM)

```bash
# Get instance ID
cd deploy/terraform && terraform output instance_id

# Connect via SSM (no SSH key needed)
aws ssm start-session --target <instance-id> --region us-east-1
```

### View Logs

```bash
# SSH to EC2 first, then:
docker logs pgl-backend -f
docker logs pgl-frontend -f

# Or via docker compose:
cd /opt/pgl
docker compose -f docker-compose.prod.yml logs -f
```

---

## SSL Certificate Management

Certificates are obtained via Let's Encrypt with DNS-01 validation (Route53).

### Check Certificate Status
```bash
# On EC2:
sudo certbot certificates
```

### Force Renewal
```bash
sudo certbot renew --force-renewal
```

### Certificates are automatically:
- Renewed twice daily via systemd timer
- Backed up to S3 after renewal
- Restored from S3 on new EC2 instances

---

## Secrets Management

Secrets are stored in AWS SSM Parameter Store.

### View Claude API Key
```bash
aws ssm get-parameter \
    --name /pgl/prod/claude-api-key \
    --with-decryption \
    --region us-east-1
```

### Update Claude API Key
```bash
aws ssm put-parameter \
    --name /pgl/prod/claude-api-key \
    --value "sk-ant-new-key-here" \
    --type SecureString \
    --overwrite \
    --region us-east-1

# Restart containers to pick up new key
./deploy/build-and-push.sh restart
```

---

## Security Features

### Development Phase (Current)

| Layer | Protection |
|-------|------------|
| Security Group | Only home IP can access |
| HTTP Basic Auth | Username/password required |
| HTTPS | All traffic encrypted |

### Production Launch

When ready for public access:

1. Update security group to allow 0.0.0.0/0 for ports 80/443
2. Remove or make auth_basic optional in nginx.conf
3. Re-run `./build-and-push.sh upload && ./build-and-push.sh restart`

---

## Troubleshooting

### Containers won't start

```bash
# SSH to EC2
aws ssm start-session --target <instance-id>

# Check container status
docker ps -a

# View container logs
docker logs pgl-backend
docker logs pgl-frontend

# Check user-data log (initial setup)
cat /var/log/user-data.log
```

### SSL certificate issues

```bash
# On EC2:
sudo certbot certificates
sudo cat /var/log/letsencrypt/letsencrypt.log
```

### EFS mount issues

```bash
# Check EFS mount
df -h | grep efs
mount | grep nfs

# Remount
sudo mount -a
```

### Database issues

```bash
# SQLite database is at /opt/pgl/data/pgl.db
sqlite3 /opt/pgl/data/pgl.db ".tables"
```

