# EFS Filesystem for persistent data (database, uploads)
resource "aws_efs_file_system" "main" {
  creation_token = "${var.project_name}-${var.environment}-efs"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-efs"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    prevent_destroy = true
  }
}

# EFS Mount Target (uses default VPC and first subnet)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_efs_mount_target" "main" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = data.aws_subnets.default.ids[0]
  security_groups = [aws_security_group.efs.id]
}

# Security group for EFS
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-${var.environment}-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "NFS from EC2"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server.id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-efs-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 Bucket for configs, SSL certs, and deployment files
resource "aws_s3_bucket" "persistent_data" {
  bucket = "${var.project_name}-${var.environment}-persistent-data"

  tags = {
    Name        = "${var.project_name}-${var.environment}-persistent-data"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning for S3 bucket
resource "aws_s3_bucket_versioning" "persistent_data" {
  bucket = aws_s3_bucket.persistent_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "persistent_data" {
  bucket = aws_s3_bucket.persistent_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "persistent_data" {
  bucket = aws_s3_bucket.persistent_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
