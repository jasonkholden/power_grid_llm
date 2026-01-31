# Secrets Management using AWS Systems Manager Parameter Store
# These parameters are encrypted at rest using AWS-managed keys

# Claude API Key (SecureString - encrypted at rest)
resource "aws_ssm_parameter" "pgl_claude_api_key" {
  name        = "/${var.project_name}/${var.environment}/claude-api-key"
  description = "Anthropic Claude API key for LLM interactions"
  type        = "SecureString"
  value       = var.claude_api_key

  tags = {
    Name        = "${var.project_name}-${var.environment}-claude-api-key"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    ignore_changes = [value] # Prevent accidental overwrites of existing values
  }
}

# OpenAI API Key (SecureString - encrypted at rest)
resource "aws_ssm_parameter" "pgl_openai_api_key" {
  name        = "/${var.project_name}/${var.environment}/openai-api-key"
  description = "OpenAI API key for LLM interactions (used by OpenAI Agents SDK)"
  type        = "SecureString"
  value       = var.openai_api_key

  tags = {
    Name        = "${var.project_name}-${var.environment}-openai-api-key"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# IAM policy to allow EC2 to read SSM parameters
resource "aws_iam_policy" "pgl_ssm_parameters" {
  name        = "${var.project_name}-${var.environment}-ssm-parameters-policy"
  description = "Allow EC2 to read SSM parameters for secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          aws_ssm_parameter.pgl_claude_api_key.arn,
          aws_ssm_parameter.pgl_openai_api_key.arn,
          aws_ssm_parameter.pgl_iso_ne_username.arn,
          aws_ssm_parameter.pgl_iso_ne_password.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*" # SSM uses default AWS managed key
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ssm-parameters-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach SSM policy to EC2 role
resource "aws_iam_role_policy_attachment" "pgl_ssm_parameters" {
  role       = aws_iam_role.pgl_ec2.name
  policy_arn = aws_iam_policy.pgl_ssm_parameters.arn
}

# ISO New England API Credentials (for MCP server)
resource "aws_ssm_parameter" "pgl_iso_ne_username" {
  name        = "/${var.project_name}/${var.environment}/iso-ne-username"
  description = "ISO New England API username for power grid data"
  type        = "SecureString"
  value       = var.iso_ne_username

  tags = {
    Name        = "${var.project_name}-${var.environment}-iso-ne-username"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "pgl_iso_ne_password" {
  name        = "/${var.project_name}/${var.environment}/iso-ne-password"
  description = "ISO New England API password for power grid data"
  type        = "SecureString"
  value       = var.iso_ne_password

  tags = {
    Name        = "${var.project_name}-${var.environment}-iso-ne-password"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# Outputs for reference
output "claude_api_key_parameter_name" {
  value       = aws_ssm_parameter.pgl_claude_api_key.name
  description = "SSM Parameter name for Claude API key"
}

output "openai_api_key_parameter_name" {
  value       = aws_ssm_parameter.pgl_openai_api_key.name
  description = "SSM Parameter name for OpenAI API key"
}

output "iso_ne_username_parameter_name" {
  value       = aws_ssm_parameter.pgl_iso_ne_username.name
  description = "SSM Parameter name for ISO-NE username"
}

output "iso_ne_password_parameter_name" {
  value       = aws_ssm_parameter.pgl_iso_ne_password.name
  description = "SSM Parameter name for ISO-NE password"
}
