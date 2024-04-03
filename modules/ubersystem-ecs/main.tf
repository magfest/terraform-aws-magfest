terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.38.0"
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

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.prefix}-uber"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  security_group_ids   = [var.redis_sg_id]
  subnet_group_name    = var.redis_subnet_group_name
}

# -------------------------------------------------------------------
# MAGFest Ubersystem Load Balancer
# -------------------------------------------------------------------

resource "aws_lb_target_group" "ubersystem_http" {
  name                 = "${var.prefix}-http"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = data.aws_vpc.uber.id
  deregistration_delay = 10

  stickiness {
    cookie_name = "session_id"
    enabled     = false
    type        = "app_cookie"
  }

  health_check {
    healthy_threshold   = 2
    interval            = 30
    unhealthy_threshold = 10
    timeout             = 5
    path                = var.health_url
    matcher             = "200,301,303"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "uber_http" {
  listener_arn = var.lb_web_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ubersystem_http.arn
  }

  condition {
    host_header {
      values = [
        var.hostname,
        "internal.${var.hostname}"
      ]
    }
  }
}

resource "aws_route53_record" "public" {
  zone_id = data.aws_route53_zone.uber.id
  name    = var.hostname
  type    = "CNAME"
  ttl     = 5
  records = [
    var.cloudfront_dns_name
  ]
}

resource "aws_route53_record" "internal" {
  zone_id = data.aws_route53_zone.uber.id
  name    = "internal.${var.hostname}"
  type    = "CNAME"
  ttl     = 5
  records = [
    var.loadbalancer_dns_name
  ]
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


resource "aws_secretsmanager_secret" "uber" {
  name                    = "${var.prefix}-uber-secrets"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "initial" {
  secret_id     = aws_secretsmanager_secret.uber.id
  secret_string = <<-EOF
  data:
    secrets: {}
  EOF
  lifecycle {
    ignore_changes = all
  }
}