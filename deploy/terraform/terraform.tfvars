# Power Grid LLM - Terraform Variables
# Non-secret values only - secrets go in terraform.tfvars.secret

aws_region    = "us-east-1"
environment   = "prod"
project_name  = "pgl"
domain_name   = "powergridllm.com"
instance_type     = "t4g.medium"

# home_ip is in terraform.tfvars.secret to avoid committing to source control

# Optional: SSH key name (leave empty to use SSM Session Manager only)
ssh_key_name = ""
