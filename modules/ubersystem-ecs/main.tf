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
# MAGFest Ubersystem Containers (web)
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

resource "aws_ecs_service" "ubersystem_web" {
  name            = "${var.prefix}_ubersystem_web"
  cluster         = var.ecs_cluster
  task_definition = aws_ecs_task_definition.ubersystem_web.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets           = var.subnet_ids
    security_groups   = var.uber_web_securitygroups
    assign_public_ip  = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ubersystem_web.arn
    container_name   = "web"
    container_port   = 8282
  }
}

resource "aws_ecs_task_definition" "ubersystem_web" {
  family                    = "${var.prefix}_ubersystem_web"
  container_definitions     = jsonencode(
    [
      {
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "/ecs/Ubersystem",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "ecs",
            "awslogs-create-group": "true"
          }
        },
        "portMappings": [
          {
            "hostPort": 8282,
            "protocol": "tcp",
            "containerPort": 8282
          }
        ],
        "environment": [
          {
            "name": "CERT_NAME",
            "value": "ssl"
          },
          {
            "name": "VIRTUAL_HOST",
            "value": var.hostname
          },
          {
            "name": "SESSION_HOST",
            "value": "redis.${var.hostname}"
          },
          {
            "name": "BROKER_HOST",
            "value": "rabbitmq.${var.hostname}"
          },
          {
            "name": "UBERSYSTEM_CONFIG",
            "value": var.ubersystem_config
          },
          {
            "name": "UBERSYSTEM_SECRETS",
            "value": var.ubersystem_secrets
          },
          {
            "name": "DB_CONNECTION_STRING",
            "value": "postgresql://${var.uber_db_username}:${aws_secretsmanager_secret_version.password.secret_string}@${var.db_endpoint}/${var.uber_db_name}"
          }
        ],
        "image": "${var.ubersystem_container}@sha256:${module.uber_image.docker_digest}",
        "essential": true,
        "name": "web",
        "mountPoints": [
          {
            "sourceVolume": "static",
            "containerPath": "/app/plugins/uber/uploaded_files",
            "readOnly": false
          }
        ]
      }
    ]
  )

  volume {
    name = "static"

    efs_volume_configuration {
      file_system_id          = var.efs_id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.uber.id
      }
    }
  }

  cpu                       = var.web_cpu
  memory                    = var.web_ram
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  execution_role_arn        = var.ecs_task_role

  task_role_arn = var.ecs_task_role

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}


# -------------------------------------------------------------------
# MAGFest Ubersystem Containers (celery)
# -------------------------------------------------------------------

resource "aws_ecs_service" "ubersystem_celery" {
  name            = "${var.prefix}_ubersystem_celery"
  cluster         = var.ecs_cluster
  task_definition = aws_ecs_task_definition.ubersystem_celery.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets           = var.subnet_ids
    assign_public_ip  = true
  }
}

resource "aws_ecs_task_definition" "ubersystem_celery" {
  family                    = "${var.prefix}_ubersystem_celery"
  container_definitions     = jsonencode(
    [
      {
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "/ecs/Ubersystem",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "ecs",
            "awslogs-create-group": "true"
          }
        },
        "command": [
          "celery-beat"
        ],
        "environment": [
          {
            "name": "DB_CONNECTION_STRING",
            "value": "postgresql://${var.uber_db_username}:${aws_secretsmanager_secret_version.password.secret_string}@${var.db_endpoint}/${var.uber_db_name}"
          },
          {
            "name": "BROKER_HOST",
            "value": "rabbitmq.${var.hostname}"
          },
          {
            "name": "UBERSYSTEM_CONFIG",
            "value": var.ubersystem_config
          },
          {
            "name": "UBERSYSTEM_SECRETS",
            "value": var.ubersystem_secrets
          },
        ],
        "image": "${var.ubersystem_container}@sha256:${module.uber_image.docker_digest}",
        "essential": true,
        "name": "celery-beat",
        "mountPoints": [
          {
            "sourceVolume": "static",
            "containerPath": "/app/plugins/uber/uploaded_files",
            "readOnly": false
          }
        ]
      },
      {
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "/ecs/Ubersystem",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "ecs",
            "awslogs-create-group": "true"
          }
        },
        "environment": [
          {
            "name": "DB_CONNECTION_STRING",
            "value": "postgresql://${var.uber_db_username}:${aws_secretsmanager_secret_version.password.secret_string}@${var.db_endpoint}/${var.uber_db_name}"
          },
          {
            "name": "BROKER_HOST",
            "value": "rabbitmq.${var.hostname}"
          },
          {
            "name": "UBERSYSTEM_CONFIG",
            "value": var.ubersystem_config
          },
          {
            "name": "UBERSYSTEM_SECRETS",
            "value": var.ubersystem_secrets
          },
        ],
        "image": "${var.ubersystem_container}@sha256:${module.uber_image.docker_digest}",
        "command": [
          "celery-worker"
        ],
        "essential": true,
        "name": "celery-worker",
        "mountPoints": [
          {
            "sourceVolume": "static",
            "containerPath": "/app/plugins/uber/uploaded_files",
            "readOnly": false
          }
        ]
      }
    ]
  )

  volume {
    name = "static"

    efs_volume_configuration {
      file_system_id          = var.efs_id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.uber.id
      }
    }
  }

  cpu                       = 256
  memory                    = 512
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  execution_role_arn        = var.ecs_task_role

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}


# -------------------------------------------------------------------
# MAGFest Ubersystem Supporting Services (RabbitMQ)
# -------------------------------------------------------------------


resource "aws_ecs_service" "rabbitmq" {
  name            = "${var.prefix}_rabbitmq"
  cluster         = var.ecs_cluster
  task_definition = aws_ecs_task_definition.rabbitmq.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets           = var.subnet_ids
    security_groups   = var.rabbitmq_securitygroups
    assign_public_ip  = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.rabbitmq.arn
  }
}

resource "aws_ecs_task_definition" "rabbitmq" {
  family                    = "${var.prefix}_rabbitmq"
  container_definitions     = jsonencode(
    [
      {
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "/ecs/Ubersystem",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "ecs",
            "awslogs-create-group": "true"
          }
        },
        "portMappings": [
          {
            "hostPort": 5672,
            "protocol": "tcp",
            "containerPort": 5672
          }
        ],
        "environment": [
          {
            "name": "RABBITMQ_DEFAULT_PASS",
            "value": "celery"
          },
          {
            "name": "RABBITMQ_DEFAULT_USER",
            "value": "celery"
          },
          {
            "name": "RABBITMQ_DEFAULT_VHOST",
            "value": "uber"
          }
        ],
        "image": "public.ecr.aws/docker/library/rabbitmq:alpine",
        "essential": true,
        "name": "rabbitmq"
      }
    ]
  )

  cpu                       = 256
  memory                    = 512
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  execution_role_arn        = var.ecs_task_role

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  task_role_arn = var.ecs_task_role
}

# -------------------------------------------------------------------
# MAGFest Ubersystem Supporting Services (Redis)
# -------------------------------------------------------------------

resource "aws_ecs_service" "redis" {
  name            = "${var.prefix}_redis"
  cluster         = var.ecs_cluster
  task_definition = aws_ecs_task_definition.redis.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets           = var.subnet_ids
    security_groups   = var.redis_securitygroups
    assign_public_ip  = true
  }
  
  service_registries {
    registry_arn = aws_service_discovery_service.redis.arn
  }
}

resource "aws_ecs_task_definition" "redis" {
  family                    = "${var.prefix}_redis"
  container_definitions     = jsonencode(
    [
      {
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "/ecs/Ubersystem",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "ecs",
            "awslogs-create-group": "true"
          }
        },
        "portMappings": [
          {
            "hostPort": 6379,
            "protocol": "tcp",
            "containerPort": 6379
          }
        ],
        "environment": [
          {
            "name": "ALLOW_EMPTY_PASSWORD",
            "value": "true"
          }
        ],
        "image": "public.ecr.aws/ubuntu/redis:latest",
        "essential": true,
        "name": "redis"
      }
    ]
  )

  cpu                       = 256
  memory                    = 512
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  execution_role_arn        = var.ecs_task_role

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  task_role_arn = "${var.ecs_task_role}"
}

# -------------------------------------------------------------------
# DNS Service Discovery
# -------------------------------------------------------------------

resource "aws_service_discovery_private_dns_namespace" "uber" {
  name        = var.hostname
  description = "Uber Internal Services (${var.hostname})"
  vpc         = data.aws_vpc.uber.id
}

resource "aws_service_discovery_service" "redis" {
  name = "redis"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.uber.id

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
  name = "rabbitmq"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.uber.id

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
