# IAM Role for EC2 instance
resource "aws_iam_role" "pgl_ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "pgl_ec2" {
  name = "${var.project_name}-${var.environment}-ec2-instance-profile"
  role = aws_iam_role.pgl_ec2.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-instance-profile"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Policy for ECR access (pull images)
resource "aws_iam_policy" "pgl_ecr_access" {
  name        = "${var.project_name}-${var.environment}-ecr-access-policy"
  description = "Allow EC2 to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = [
          aws_ecr_repository.pgl_frontend.arn,
          aws_ecr_repository.pgl_backend.arn,
          aws_ecr_repository.pgl_mcp_server.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecr-access-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "pgl_ecr_access" {
  role       = aws_iam_role.pgl_ec2.name
  policy_arn = aws_iam_policy.pgl_ecr_access.arn
}

# Policy for S3 access (configs and SSL certs)
resource "aws_iam_policy" "pgl_s3_access" {
  name        = "${var.project_name}-${var.environment}-s3-access-policy"
  description = "Allow EC2 to read/write configs and SSL certs in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.pgl_persistent_data.arn,
          "${aws_s3_bucket.pgl_persistent_data.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-access-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "pgl_s3_access" {
  role       = aws_iam_role.pgl_ec2.name
  policy_arn = aws_iam_policy.pgl_s3_access.arn
}

# Policy for Route53 access (certbot DNS-01 validation)
resource "aws_iam_policy" "pgl_route53_certbot" {
  name        = "${var.project_name}-${var.environment}-route53-certbot-policy"
  description = "Allow certbot to manage Route53 DNS records for SSL validation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:GetChange"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${data.aws_route53_zone.pgl_main.zone_id}"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-route53-certbot-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "pgl_route53_certbot" {
  role       = aws_iam_role.pgl_ec2.name
  policy_arn = aws_iam_policy.pgl_route53_certbot.arn
}

# SSM Session Manager policy (for SSH-less access)
resource "aws_iam_role_policy_attachment" "pgl_ssm_managed" {
  role       = aws_iam_role.pgl_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
