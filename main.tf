terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.38.0"
    }
  }
}

# -------------------------------------------------------------------
# VPC
# -------------------------------------------------------------------

resource "aws_vpc" "uber" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  
  tags = {
    Name = "Ubersystem"
  }
}

# -------------------------------------------------------------------
# Security Groups
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

resource "aws_security_group" "uber_rabbitmq" {
  name        = "uber_rabbitmq"
  description = "Allow ALB to reach RabbitMQ"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "RabbitMQ"
    from_port        = 5672
    to_port          = 5672
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
    Name = "Ubersystem RabbitMQ"
  }
}

resource "aws_security_group" "uber_redis" {
  name        = "uber_redis"
  description = "Allow Ubersystem to reach Redis"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "Ubersystem Redis"
    from_port        = 6379
    to_port          = 6379
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
    Name = "Ubersystem Redis"
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

resource "aws_security_group" "uber_rds" {
  name        = "uber_rds"
  description = "Allow access to Uber RDS"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "Postgres"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [
        aws_subnet.primary.cidr_block,
        aws_subnet.secondary.cidr_block,
        "0.0.0.0/0"
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
    Name = "Ubersystem Public"
  }
}

# -------------------------------------------------------------------
# Subnets
# -------------------------------------------------------------------

resource "aws_subnet" "primary" {
  vpc_id                  = aws_vpc.uber.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "Ubersystem Primary"
  }
}

resource "aws_subnet" "secondary" {
  vpc_id                  = aws_vpc.uber.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Ubersystem Secondary"
  }
}

resource "aws_db_subnet_group" "uber" {
  name       = "uber"
  subnet_ids = [
    aws_subnet.primary.id,
    aws_subnet.secondary.id
  ]

  tags = {
    Name = "Ubersystem"
  }
}

# -------------------------------------------------------------------
# Routes and Gateways
# -------------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.uber.id

  tags = {
    Name = "Ubersystem"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.uber.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "primary_route" {
  subnet_id      = aws_subnet.primary.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "secondary_route" {
  subnet_id      = aws_subnet.secondary.id
  route_table_id = aws_route_table.public.id
}

# -------------------------------------------------------------------
# ECS Cluster
# -------------------------------------------------------------------

resource "aws_ecs_cluster" "uber" {
  name = "Ubersystem"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_iam_role" "task_role" {
  name_prefix = "uber"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

# -------------------------------------------------------------------
# Load Balancer
# -------------------------------------------------------------------

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
  name_prefix        = "uber"
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

# -------------------------------------------------------------------
# Elastic File System
# -------------------------------------------------------------------

resource "aws_efs_file_system" "ubersystem_static" {
  creation_token = "ubersystem"

  tags = {
    Name = "Ubersystem"
  }
}

# -------------------------------------------------------------------
# RDS
# -------------------------------------------------------------------

resource "random_password" "uber" {
  length            = 40
  special           = false
  keepers           = {
    pass_version  = 2
  }
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "ubersystem-db-password"
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.uber.result
}

resource "aws_db_instance" "uber" {
  allocated_storage      = 10
  db_name                = "uber"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  username               = "postgres"
  password               = aws_secretsmanager_secret_version.password.secret_string
  skip_final_snapshot    = true
  multi_az               = false
  publicly_accessible    = true
  vpc_security_group_ids = [
    aws_security_group.uber_rds.id
  ]
  db_subnet_group_name   = aws_db_subnet_group.uber.name
}