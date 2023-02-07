terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.38.0"
    }
    postgresql = {
      source = "cyrilgdn/postgresql"
    }
    curl = {
      source = "marcofranssen/curl"
    }
  }
}

# -------------------------------------------------------------------
# Import Data block for AWS information
# -------------------------------------------------------------------

data "aws_vpc" "uber" {
  id = var.vpc_id
}

data "aws_route53_zone" "uber" {
  name = var.zonename
  private_zone = false
}

module "uber_image" {
  source = "./modules/docker-resolve"
  image = var.ubersystem_container
}

# -------------------------------------------------------------------
# MAGFest Ubersystem Load Balancer
# -------------------------------------------------------------------

resource "aws_acm_certificate" "uber" {
  domain_name       = var.hostname
  validation_method = "DNS"
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

resource "aws_route53_record" "public" {
  zone_id = data.aws_route53_zone.uber.id
  name    = var.hostname
  type    = "CNAME"
  ttl     = 5
  records = [
    var.loadbalancer_dns_name
  ]
}

resource "aws_lb_target_group" "ubersystem_web" {
  name                 = "${var.prefix}-web"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_vpc.uber.id
  deregistration_delay = 10

  stickiness {
    cookie_name = "session_id"
    enabled     = true
    type        = "app_cookie"
  }

  health_check {
    healthy_threshold   = 2
    interval            = 30
    unhealthy_threshold = 10
    timeout             = 5
    path                = "/"
    matcher             = "200-499"
  }
}

resource "aws_lb_listener_certificate" "uber" {
  listener_arn    = var.lb_web_listener_arn
  certificate_arn = aws_acm_certificate_validation.uber.certificate_arn
}

resource "aws_lb_listener_rule" "uber" {
  listener_arn = var.lb_web_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ubersystem_web.arn
  }

  condition {
    host_header {
      values = [var.hostname]
    }
  }
}

# -------------------------------------------------------------------
# DNS Service Discovery
# -------------------------------------------------------------------

resource "aws_service_discovery_private_dns_namespace" "uber" {
  count = var.layout == "scalable" ? 1 : 0
  name        = var.private_zone
  description = "Uber Internal Services (${var.hostname})"
  vpc         = data.aws_vpc.uber.id
}

resource "aws_service_discovery_service" "redis" {
  count = var.layout == "scalable" ? 1 : 0
  name          = "redis"
  force_destroy = true

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.uber[count.index].id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "rabbitmq" {
  count = var.layout == "scalable" ? 1 : 0
  name          = "rabbitmq"
  force_destroy = true

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.uber[count.index].id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# -------------------------------------------------------------------
# Database
# -------------------------------------------------------------------

resource "random_password" "uber" {
  length            = 40
  special           = false
  keepers           = {
    pass_version  = 2
  }
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.prefix}-rds-passwd"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.uber.result
}

resource "postgresql_database" "uber" {
  name              = var.uber_db_name
  owner             = var.uber_db_username
  template          = "template0"
  lc_collate        = "C"
  connection_limit  = -1
  allow_connections = true
  depends_on = [
    postgresql_role.uber
  ]
}

resource "postgresql_role" "uber" {
  name             = var.uber_db_username
  login            = true
  connection_limit = -1
  password         = aws_secretsmanager_secret_version.password.secret_string
}

# -------------------------------------------------------------------
# EFS Filesystem
# -------------------------------------------------------------------

resource "aws_efs_access_point" "uber" {
  file_system_id = var.efs_id

  root_directory {
    path = var.efs_dir
    creation_info {
      owner_gid   = 65534
      owner_uid   = 65534
      permissions = 0755
    }
  }

  tags = {
    Name = "${var.prefix}-static"
  }
}

# -------------------------------------------------------------------
# Configuration Secrets
# -------------------------------------------------------------------

resource "aws_secretsmanager_secret" "uber_secret" {
  name = "${var.prefix}-config"
  recovery_window_in_days = 0
}