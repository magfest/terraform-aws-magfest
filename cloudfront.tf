resource "aws_cloudfront_distribution" "ubersystem" {
  origin {
    domain_name                = aws_lb.ubersystem.dns_name
    origin_id                  = "Ubersystem"
    custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_ssl_protocols   = ["TLSv1.2"]
        origin_protocol_policy = "http-only"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true

  aliases = [for server in local.servers : server.hostname]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "Ubersystem"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 900
    max_ttl                = 3600

    forwarded_values {
      query_string = true
      headers = ["*"]

      cookies {
        forward = "all"
      }
    }
  }

/*
# Disabling static asset cache until Cookie handling is fixed
  ordered_cache_behavior {
    path_pattern     = "/static*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "Ubersystem"

    min_ttl                = 0
    default_ttl            = 900
    max_ttl                = 3600
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      headers = ["Host"]

      cookies {
        forward = "none"
      }
    }
  }
*/

  price_class = "PriceClass_100"

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.uber.arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }
}

resource "aws_route53_record" "default" {
  zone_id = data.aws_route53_zone.uber.zone_id
  name    = var.hostname
  type    = "CNAME"
  ttl     = 300
  records = [aws_cloudfront_distribution.ubersystem.domain_name]
}

resource "aws_acm_certificate" "uber" {
  domain_name       = var.hostname
  subject_alternative_names = [for server in local.servers : server.hostname]
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
