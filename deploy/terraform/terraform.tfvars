# Power Grid LLM - Terraform Variables
# Non-secret values only - secrets go in terraform.tfvars.secret

aws_region    = "us-east-1"
environment   = "prod"
project_name  = "pgl"
domain_name   = "powergridllm.com"
instance_type = "t4g.nano"

# Your home IP for restricted access during development
# Get your IP with: curl ifconfig.me
home_ip = "0.0.0.0/32"  # TODO: Update with your home IP (e.g., "1.2.3.4/32")

# Optional: SSH key name (leave empty to use SSM Session Manager only)
ssh_key_name = ""
