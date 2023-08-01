# -------------------------------------------------------------------
# Load Balancer
# -------------------------------------------------------------------

resource "aws_security_group" "uber_backend" {
  name        = "uber_backend"
  description = "Allow ALB to reach Uber"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "HTTP to Ubersystem Web"
    from_port        = 8282
    to_port          = 8282
    protocol         = "tcp"
    cidr_blocks      = [
      aws_subnet.primary.cidr_block,
      aws_subnet.secondary.cidr_block
    ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Ubersystem Backend"
  }
}

resource "aws_security_group" "uber_public" {
  name        = "uber_public"
  description = "Allow the Internet to reach Uber"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "Ubersystem HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Ubersystem HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Ubersystem Public"
  }
}

resource "aws_acm_certificate" "uber" {
  domain_name       = var.hostname
  validation_method = "DNS"
}

data "aws_route53_zone" "uber" {
  name         = var.zonename
  private_zone = false
}

resource "aws_route53_record" "uber" {
  for_each = {
    for dvo in aws_acm_certificate.uber.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.uber.zone_id
}

resource "aws_acm_certificate_validation" "uber" {
  certificate_arn         = aws_acm_certificate.uber.arn
  validation_record_fqdns = [for record in aws_route53_record.uber : record.fqdn]
}

resource "aws_lb" "ubersystem" {
  name               = "Ubersystem"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [
    aws_security_group.uber_public.id
  ]
  subnets            = [
    aws_subnet.primary.id,
    aws_subnet.secondary.id
  ]

  enable_deletion_protection = false
}

resource "aws_route53_record" "default" {
  zone_id = data.aws_route53_zone.uber.zone_id
  name    = var.hostname
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.ubersystem.dns_name]
}

resource "aws_lb_listener" "ubersystem_web_http" {
  load_balancer_arn = aws_lb.ubersystem.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "ubersystem_web_https" {
  load_balancer_arn = aws_lb.ubersystem.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.uber.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Unknown ubersystem endpoint"
      status_code  = "404"
    }
  }
}
