# Route53 A record pointing to the Elastic IP
resource "aws_route53_record" "pgl_main" {
  zone_id = data.aws_route53_zone.pgl_main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.pgl_main.public_ip]
}

# Optional: www subdomain redirect
resource "aws_route53_record" "pgl_www" {
  zone_id = data.aws_route53_zone.pgl_main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.pgl_main.public_ip]
}
