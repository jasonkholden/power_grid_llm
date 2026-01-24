# Security group for the EC2 instance
# Restricts access to home IP only during development
resource "aws_security_group" "pgl_web_server" {
  name        = "${var.project_name}-${var.environment}-sec-group-home-access-only"
  description = "Security group for web server - home access only during development"

  # SSH from home IP only
  ingress {
    description = "SSH from home"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.home_ip]
  }

  # HTTP from home IP only (for Let's Encrypt and redirect)
  ingress {
    description = "HTTP from home"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.home_ip]
  }

  # HTTPS from home IP only
  ingress {
    description = "HTTPS from home"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.home_ip]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-sec-group-home-access-only"
    Environment = var.environment
    Project     = var.project_name
  }
}
