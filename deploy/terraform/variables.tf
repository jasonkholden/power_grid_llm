variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "pgl"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "powergridllm.com"
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt notifications"
  type        = string
  sensitive   = true
}

variable "home_ip" {
  description = "Home IP address for SSH/HTTP/HTTPS access (CIDR notation, e.g., 1.2.3.4/32)"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair in AWS (optional, SSM Session Manager is preferred)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type (ARM-based for cost savings)"
  type        = string
  default     = "t4g.nano"
}

# ============================================
# Secrets - provide via terraform.tfvars.secret
# ============================================

variable "claude_api_key" {
  description = "Anthropic Claude API key for LLM interactions"
  type        = string
  sensitive   = true
}

variable "http_auth_line" {
  description = "HTTP basic auth credentials for nginx (username:hashed_password). Generate with: htpasswd -n username"
  type        = string
  sensitive   = true
}
