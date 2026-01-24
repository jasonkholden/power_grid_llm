# SSH Key Pair for EC2 access
resource "aws_key_pair" "pgl_ec2" {
  key_name   = "${var.project_name}-${var.environment}-ec2-key"
  public_key = var.ssh_public_key

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-key"
    Environment = var.environment
    Project     = var.project_name
  }
}

# EC2 Instance for running the application
resource "aws_instance" "pgl_main" {
  ami                    = data.aws_ami.pgl_ubuntu.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.pgl_ec2.name
  subnet_id              = data.aws_subnet.pgl_default.id
  vpc_security_group_ids = [aws_security_group.pgl_web_server.id]
  key_name               = aws_key_pair.pgl_ec2.key_name

  # User data script for instance initialization
  user_data = templatefile("${path.module}/../user-data.sh", {
    PROJECT_NAME      = var.project_name
    ENVIRONMENT       = var.environment
    AWS_REGION        = var.aws_region
    DOMAIN_NAME       = var.domain_name
    LETSENCRYPT_EMAIL = var.letsencrypt_email
    EFS_ID            = aws_efs_file_system.pgl_main.id
    S3_BUCKET         = aws_s3_bucket.pgl_persistent_data.id
    ECR_FRONTEND      = aws_ecr_repository.pgl_frontend.repository_url
    ECR_BACKEND       = aws_ecr_repository.pgl_backend.repository_url
    HTTP_AUTH_LINE    = var.http_auth_line
    APP_DIR           = "/opt/${var.project_name}"
    # SSM parameter names for secrets
    CLAUDE_API_KEY_PARAM = aws_ssm_parameter.pgl_claude_api_key.name
  })

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Wait for EFS mount target before creating instance
  depends_on = [aws_efs_mount_target.pgl_main]

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Elastic IP for stable public IP
resource "aws_eip" "pgl_main" {
  instance = aws_instance.pgl_main.id
  domain   = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-eip"
    Environment = var.environment
    Project     = var.project_name
  }
}
