# EFS Filesystem for persistent data (database, uploads)
resource "aws_efs_file_system" "pgl_main" {
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

# EFS Mount Target (uses default VPC and a specific subnet for consistency)
data "aws_vpc" "pgl_default" {
  default = true
}

# Get first available subnet for consistent placement
data "aws_subnet" "pgl_default" {
  vpc_id            = data.aws_vpc.pgl_default.id
  availability_zone = data.aws_availability_zones.pgl_available.names[0]
  default_for_az    = true
}

resource "aws_efs_mount_target" "pgl_main" {
  file_system_id  = aws_efs_file_system.pgl_main.id
  subnet_id       = data.aws_subnet.pgl_default.id
  security_groups = [aws_security_group.pgl_efs.id]
}

# Security group for EFS
resource "aws_security_group" "pgl_efs" {
  name        = "${var.project_name}-${var.environment}-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = data.aws_vpc.pgl_default.id

  ingress {
    description     = "NFS from EC2"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.pgl_web_server.id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-efs-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 Bucket for configs, SSL certs, and deployment files
resource "aws_s3_bucket" "pgl_persistent_data" {
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
resource "aws_s3_bucket_versioning" "pgl_persistent_data" {
  bucket = aws_s3_bucket.pgl_persistent_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "pgl_persistent_data" {
  bucket = aws_s3_bucket.pgl_persistent_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "pgl_persistent_data" {
  bucket = aws_s3_bucket.pgl_persistent_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
