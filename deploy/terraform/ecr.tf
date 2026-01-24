# ECR Repository for Frontend Docker images
resource "aws_ecr_repository" "pgl_frontend" {
  name                 = "${var.project_name}-${var.environment}-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-frontend"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECR Repository for Backend Docker images
resource "aws_ecr_repository" "pgl_backend" {
  name                 = "${var.project_name}-${var.environment}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lifecycle policy to keep only last 5 images (cost savings)
resource "aws_ecr_lifecycle_policy" "pgl_frontend" {
  repository = aws_ecr_repository.pgl_frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "pgl_backend" {
  repository = aws_ecr_repository.pgl_backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository for MCP Server Docker images
# Note: The MCP server code lives in a separate repo (ne_power_grid_mcp_server)
# but we manage its ECR repository here for infrastructure consistency
resource "aws_ecr_repository" "pgl_mcp_server" {
  name                 = "${var.project_name}-${var.environment}-mcp-server"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-mcp-server"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecr_lifecycle_policy" "pgl_mcp_server" {
  repository = aws_ecr_repository.pgl_mcp_server.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
