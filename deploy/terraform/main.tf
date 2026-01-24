terraform {
  required_version = ">= 1.0"

  # Remote state storage in S3 with DynamoDB locking
  # NOTE: You must create the S3 bucket and DynamoDB table BEFORE running terraform init
  # See DEPLOYMENT.md for instructions
  backend "s3" {
    bucket         = "powergridllm-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "powergridllm-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source to get the Route53 hosted zone (must exist)
data "aws_route53_zone" "pgl_main" {
  name = var.domain_name
}

# Get available availability zones
data "aws_availability_zones" "pgl_available" {
  state = "available"
}

# Get current AWS account ID
data "aws_caller_identity" "pgl_current" {}

# Get the latest Ubuntu 24.04 ARM64 AMI
data "aws_ami" "pgl_ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}
