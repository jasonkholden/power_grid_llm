# GitHub Actions Deployment Migration

## Overview
Migrate from manual `build-and-push.sh` deployment to automated GitHub Actions CI/CD pipeline.

## Current State
- Manual deployment via `./deploy/build-and-push.sh all`
- Terraform manages infrastructure (ECR, EC2, S3, SSM)
- Deployment triggers EC2 restart via SSM

## Target State
- Push to `master` triggers automatic deployment
- PRs run build/lint checks before merge
- Secrets managed via GitHub Secrets

---

## Phase 1: IAM User for CI/CD

### Option A: Manual IAM User
Create IAM user `pgl-github-actions` with policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "ECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": [
        "arn:aws:ecr:us-east-1:*:repository/pgl-prod-frontend",
        "arn:aws:ecr:us-east-1:*:repository/pgl-prod-backend"
      ]
    },
    {
      "Sid": "S3ConfigUpload",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::pgl-prod-*/*"
    },
    {
      "Sid": "SSMSendCommand",
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand",
        "ssm:GetCommandInvocation"
      ],
      "Resource": "*"
    }
  ]
}
```

### Option B: Terraform-managed IAM User
Add to `deploy/terraform/iam.tf`:
- `aws_iam_user.github_actions`
- `aws_iam_user_policy.github_actions`
- Output access key (or use OIDC - see Phase 4)

---

## Phase 2: GitHub Repository Secrets

Add these secrets in GitHub → Settings → Secrets:

| Secret | Source |
|--------|--------|
| `AWS_ACCESS_KEY_ID` | IAM user credentials |
| `AWS_SECRET_ACCESS_KEY` | IAM user credentials |
| `AWS_REGION` | `us-east-1` |
| `AWS_ACCOUNT_ID` | `terraform output aws_account_id` |
| `EC2_INSTANCE_ID` | `terraform output instance_id` |
| `S3_BUCKET_NAME` | `terraform output s3_bucket_name` |
| `DOMAIN_NAME` | `powergridllm.com` |

---

## Phase 3: GitHub Actions Workflows

### File: `.github/workflows/deploy.yml`
```yaml
name: Deploy to AWS

on:
  push:
    branches: [master]

env:
  AWS_REGION: ${{ secrets.AWS_REGION }}

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push backend image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        run: |
          docker build -t $ECR_REGISTRY/pgl-prod-backend:latest \
            -f backend/Dockerfile --target runtime backend/
          docker push $ECR_REGISTRY/pgl-prod-backend:latest

      - name: Build and push frontend image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        run: |
          docker build -t $ECR_REGISTRY/pgl-prod-frontend:latest \
            -f frontend/Dockerfile --target production frontend/
          docker push $ECR_REGISTRY/pgl-prod-frontend:latest

      - name: Upload configs to S3
        run: |
          sed "s/\${DOMAIN_NAME}/${{ secrets.DOMAIN_NAME }}/g" \
            deploy/nginx.conf > /tmp/nginx.conf
          aws s3 cp deploy/docker-compose.prod.yml \
            s3://${{ secrets.S3_BUCKET_NAME }}/config/docker-compose.prod.yml
          aws s3 cp /tmp/nginx.conf \
            s3://${{ secrets.S3_BUCKET_NAME }}/config/nginx.conf

      - name: Restart containers on EC2
        run: |
          aws ssm send-command \
            --instance-ids "${{ secrets.EC2_INSTANCE_ID }}" \
            --document-name "AWS-RunShellScript" \
            --parameters 'commands=[
              "cd /opt/pgl",
              "aws ecr get-login-password --region ${{ secrets.AWS_REGION }} | docker login --username AWS --password-stdin ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ secrets.AWS_REGION }}.amazonaws.com",
              "aws s3 cp s3://${{ secrets.S3_BUCKET_NAME }}/config/docker-compose.prod.yml docker-compose.prod.yml",
              "aws s3 cp s3://${{ secrets.S3_BUCKET_NAME }}/config/nginx.conf nginx/nginx.conf",
              "docker compose -f docker-compose.prod.yml --env-file .env pull",
              "docker compose -f docker-compose.prod.yml --env-file .env up -d"
            ]'
```

### File: `.github/workflows/ci.yml` (PR checks)
```yaml
name: CI

on:
  pull_request:
    branches: [master]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Build backend image
        run: docker build -f backend/Dockerfile --target runtime backend/

      - name: Build frontend image
        run: docker build -f frontend/Dockerfile --target production frontend/

  # Future: add linting, tests
```

---

## Phase 4: Future Improvements

### OIDC Authentication (No long-lived keys)
Replace IAM user access keys with GitHub OIDC:
- More secure (short-lived tokens)
- No secrets to rotate
- Requires additional Terraform for OIDC provider

### Branch Protection Rules
- Require CI to pass before merge
- Require PR reviews
- Prevent force push to master 

### Environments
- Create `production` environment in GitHub
- Require approval before deploy
- Environment-specific secrets

### Caching
- Cache Docker layers for faster builds
- Cache node_modules

### Notifications
- Slack/Discord notifications on deploy
- Failure alerts

---

## Implementation Checklist

- [ ] Create IAM user with required permissions
- [ ] Add GitHub Secrets (7 secrets)
- [ ] Create `.github/workflows/deploy.yml`
- [ ] Create `.github/workflows/ci.yml`
- [ ] Test PR workflow on a feature branch
- [ ] Test deploy workflow on merge to master
- [ ] Set up branch protection rules
- [ ] Document in DEPLOYMENT.md
- [ ] (Optional) Migrate to OIDC authentication
