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
          aws_ssm_parameter.pgl_claude_api_key.arn
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

# Outputs for reference
output "claude_api_key_parameter_name" {
  value       = aws_ssm_parameter.pgl_claude_api_key.name
  description = "SSM Parameter name for Claude API key"
}
