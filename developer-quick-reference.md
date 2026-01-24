# Power Grid LLM - Developer Quick Reference

## Local Environment

```bash
# Start local dev environment
docker-compose up --build

# Open in browser
open http://localhost:3001

# Stop local environment
docker-compose down

# View logs
docker-compose logs -f backend
docker-compose logs -f frontend

# Rebuild single service
docker-compose up --build backend

# Reset database (delete volume)
docker-compose down -v
```

## Production Deployment

```bash
# Full deployment (build, push, restart)
./deploy/build-and-push.sh all

# Build images only
./deploy/build-and-push.sh build

# Push to ECR only
./deploy/build-and-push.sh push

# Upload configs to S3
./deploy/build-and-push.sh upload

# Restart containers on EC2
./deploy/build-and-push.sh restart
```

## Terraform

```bash
cd deploy/terraform

# Initialize terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Show outputs
terraform output

# Destroy infrastructure (CAREFUL!)
terraform destroy
```

## AWS Debug / SSH Access

```bash
# Get instance ID
cd deploy/terraform && terraform output instance_id

# Connect via SSM Session Manager (no SSH key needed)
aws ssm start-session --target <instance-id> --region us-east-1

# Check container status on EC2
docker ps
docker compose -f /opt/pgl/docker-compose.prod.yml logs -f

# View user-data log (initial setup)
cat /var/log/user-data.log
```

## Database Access

```bash
# Local: SQLite in docker volume
docker-compose exec backend sqlite3 /data/pgl.db

# Production: SSH first, then
sqlite3 /opt/pgl/data/pgl.db
```

## SSL Certificate Management

```bash
# On EC2 - check certificate status
sudo certbot certificates

# Force renewal
sudo certbot renew --force-renewal

# View renewal timer
systemctl status certbot.timer

# View certbot logs
sudo cat /var/log/letsencrypt/letsencrypt.log
```

## Secrets Management

```bash
# View Claude API key in SSM
aws ssm get-parameter \
    --name /pgl/prod/claude-api-key \
    --with-decryption \
    --region us-east-1

# Update Claude API key
aws ssm put-parameter \
    --name /pgl/prod/claude-api-key \
    --value "sk-ant-new-key" \
    --type SecureString \
    --overwrite \
    --region us-east-1
```

## Useful URLs

| Environment | URL |
|-------------|-----|
| Local Frontend | http://localhost:3001 |
| Local Backend | http://localhost:8001/api/health |
| Production | https://powergridllm.com |

## Quick Checks

```bash
# Get your public IP (for security group)
curl ifconfig.me

# Generate HTTP auth password
htpasswd -n admin

# Check Docker disk usage
docker system df

# Clean up Docker
docker system prune -a
```
