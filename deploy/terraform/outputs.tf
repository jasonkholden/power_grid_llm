# EC2 Instance Outputs
output "instance_id" {
  value       = aws_instance.pgl_main.id
  description = "EC2 instance ID"
}

output "instance_public_ip" {
  value       = aws_eip.pgl_main.public_ip
  description = "Elastic IP address"
}

# ECR Repository URLs
output "ecr_frontend_url" {
  value       = aws_ecr_repository.pgl_frontend.repository_url
  description = "ECR repository URL for frontend"
}

output "ecr_backend_url" {
  value       = aws_ecr_repository.pgl_backend.repository_url
  description = "ECR repository URL for backend"
}

# Storage Outputs
output "efs_id" {
  value       = aws_efs_file_system.pgl_main.id
  description = "EFS filesystem ID"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.pgl_persistent_data.id
  description = "S3 bucket name for persistent data"
}

# DNS Outputs
output "domain_name" {
  value       = var.domain_name
  description = "Domain name for the application"
}

output "route53_zone_id" {
  value       = data.aws_route53_zone.pgl_main.zone_id
  description = "Route53 hosted zone ID"
}

# Useful connection commands
output "ssm_connect_command" {
  value       = "aws ssm start-session --target ${aws_instance.pgl_main.id} --region ${var.aws_region}"
  description = "Command to connect to EC2 via SSM Session Manager"
}

output "ssh_connect_command" {
  value       = var.ssh_key_name != "" ? "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_eip.pgl_main.public_ip}" : "SSH key not configured - use SSM Session Manager"
  description = "Command to connect to EC2 via SSH (if key configured)"
}

# AWS Account Info
output "aws_account_id" {
  value       = data.aws_caller_identity.pgl_current.account_id
  description = "AWS Account ID"
}

output "aws_region" {
  value       = var.aws_region
  description = "AWS Region"
}
