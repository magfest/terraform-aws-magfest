locals {
    session_host = var.layout == "single" ? "localhost" : "redis.${var.private_zone}"
    broker_host = var.layout == "single" ? "localhost" : "rabbitmq.${var.private_zone}"
    container_web = {
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
                "value": local.session_host
            },
            {
                "name": "BROKER_HOST",
                "value": local.broker_host
            },
            {
                "name": "DB_CONNECTION_STRING",
                "value": "postgresql://${var.uber_db_username}:${aws_secretsmanager_secret_version.password.secret_string}@${var.db_endpoint}/${var.uber_db_name}"
            },
            {
                "name": "UBERSYSTEM_CONFIG_VERSION",
                "value": sha256(aws_secretsmanager_secret_version.current_config.secret_string)
            }
        ],
        "secrets": [
          {
            "name": "UBERSYSTEM_CONFIG",
            "valueFrom": aws_secretsmanager_secret.uber_config.arn
          },
          {
            "name": "UBERSYSTEM_SECRETS",
            "valueFrom": aws_secretsmanager_secret.uber_secret.arn
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
        ],
        "memoryReservation": 128
    }
    container_celery_beat = {
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
                "value": local.broker_host
            },
            {
                "name": "UBERSYSTEM_CONFIG_VERSION",
                "value": sha256(aws_secretsmanager_secret_version.current_config.secret_string)
            }
        ],
        "secrets": [
          {
            "name": "UBERSYSTEM_CONFIG",
            "valueFrom": aws_secretsmanager_secret.uber_config.arn
          },
          {
            "name": "UBERSYSTEM_SECRETS",
            "valueFrom": aws_secretsmanager_secret.uber_secret.arn
          }
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
        ],
        "memoryReservation": 128
    }
    container_celery_worker = {
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
                "value": local.broker_host
            },
            {
                "name": "UBERSYSTEM_CONFIG_VERSION",
                "value": sha256(aws_secretsmanager_secret_version.current_config.secret_string)
            }
        ],
        "secrets": [
          {
            "name": "UBERSYSTEM_CONFIG",
            "valueFrom": aws_secretsmanager_secret.uber_config.arn
          },
          {
            "name": "UBERSYSTEM_SECRETS",
            "valueFrom": aws_secretsmanager_secret.uber_secret.arn
          }
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
        ],
        "memoryReservation": 128
    }
    container_rabbitmq = {
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
        "name": "rabbitmq",
        "mountPoints": [],
        "memoryReservation": 128
    }
    container_redis = {
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
        "name": "redis",
        "mountPoints": [],
        "memoryReservation": 64
    }
}

resource "aws_secretsmanager_secret" "uber_config" {
  name = "${var.prefix}-uber-config"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "current_config" {
  secret_id = aws_secretsmanager_secret.uber_config.id
  secret_string = var.ubersystem_config
}

# -------------------------------------------------------------------
# MAGFest Ubersystem Supporting Services (Web / Combined)
# -------------------------------------------------------------------

resource "aws_ecs_service" "ubersystem_web" {
  count = 1
  name                   = "${var.prefix}_ubersystem_web"
  cluster                = var.ecs_cluster
  task_definition        = aws_ecs_task_definition.ubersystem_web.arn
  desired_count          = var.web_count
  enable_execute_command = true
  launch_type            = var.launch_type

  network_configuration {
    subnets           = var.subnet_ids
    security_groups   = var.uber_web_securitygroups
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ubersystem_web.arn
    container_name   = "web"
    container_port   = 8282
  }
}

resource "aws_ecs_task_definition" "ubersystem_web" {
  family                    = "${var.prefix}_ubersystem_web"
  # There has to be a cleaner way to do this, but I don't really understand how types work here.
  # Only deploy web/redis unless enable_workers is true
  container_definitions     = jsonencode(slice(
    [
      local.container_web,
      local.container_redis,
      local.container_rabbitmq,
      local.container_celery_beat,
      local.container_celery_worker
    ],
    0,
    var.layout == "single" ? (var.enable_workers ? 5 : 2) : 1
  ))

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
  network_mode              = "awsvpc"
  execution_role_arn        = var.ecs_task_role

  task_role_arn = var.ecs_task_role
}

# -------------------------------------------------------------------
# MAGFest Ubersystem Containers (celery)
# -------------------------------------------------------------------

resource "aws_ecs_service" "ubersystem_celery" {
  count = var.layout == "scalable" && var.enable_workers ? 1 : 0
  name                   = "${var.prefix}_ubersystem_celery"
  cluster                = var.ecs_cluster
  task_definition        = aws_ecs_task_definition.ubersystem_celery[count.index].arn
  desired_count          = var.celery_count
  enable_execute_command = true
  launch_type            = var.launch_type

  network_configuration {
    subnets           = var.subnet_ids
  }
}

resource "aws_ecs_task_definition" "ubersystem_celery" {
  count = var.layout == "scalable" && var.enable_workers ? 1 : 0
  family                    = "${var.prefix}_ubersystem_celery"
  container_definitions     = jsonencode(
    [
      local.container_celery_beat,
      local.container_celery_worker
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

  cpu                       = var.celery_cpu
  memory                    = var.celery_ram
  network_mode              = "awsvpc"
  execution_role_arn        = var.ecs_task_role
  task_role_arn             = var.ecs_task_role

  depends_on = [
    aws_service_discovery_service.rabbitmq
  ]
}


# -------------------------------------------------------------------
# MAGFest Ubersystem Supporting Services (RabbitMQ)
# -------------------------------------------------------------------


resource "aws_ecs_service" "rabbitmq" {
  count = var.layout == "scalable" ? 1 : 0
  name                   = "${var.prefix}_rabbitmq"
  cluster                = var.ecs_cluster
  task_definition        = aws_ecs_task_definition.rabbitmq[count.index].arn
  desired_count          = var.rabbitmq_count
  enable_execute_command = true
  launch_type            = var.launch_type

  network_configuration {
    subnets           = var.subnet_ids
    security_groups   = var.rabbitmq_securitygroups
  }

  service_registries {
    registry_arn = aws_service_discovery_service.rabbitmq[count.index].arn
  }
}

resource "aws_ecs_task_definition" "rabbitmq" {
  count = var.layout == "scalable" ? 1 : 0
  family                    = "${var.prefix}_rabbitmq"
  container_definitions     = jsonencode(
    [
      local.container_rabbitmq
    ]
  )

  cpu                       = var.rabbitmq_cpu
  memory                    = var.rabbitmq_ram
  network_mode              = "awsvpc"
  execution_role_arn        = var.ecs_task_role

  task_role_arn = var.ecs_task_role

  depends_on = [
    aws_service_discovery_service.rabbitmq
  ]
}

# -------------------------------------------------------------------
# MAGFest Ubersystem Supporting Services (Redis)
# -------------------------------------------------------------------

resource "aws_ecs_service" "redis" {
  count = var.layout == "scalable" ? 1 : 0
  name                   = "${var.prefix}_redis"
  cluster                = var.ecs_cluster
  task_definition        = aws_ecs_task_definition.redis[count.index].arn
  desired_count          = var.redis_count
  enable_execute_command = true
  launch_type            = var.launch_type

  network_configuration {
    subnets           = var.subnet_ids
    security_groups   = var.redis_securitygroups
  }
  
  service_registries {
    registry_arn = aws_service_discovery_service.redis[count.index].arn
  }
}

resource "aws_ecs_task_definition" "redis" {
  count = var.layout == "scalable" ? 1 : 0
  family                    = "${var.prefix}_redis"
  container_definitions     = jsonencode(
    [
      local.container_redis
    ]
  )

  cpu                       = var.redis_cpu
  memory                    = var.redis_ram
  network_mode              = "awsvpc"
  execution_role_arn        = var.ecs_task_role

  task_role_arn = "${var.ecs_task_role}"

  depends_on = [
    aws_service_discovery_service.redis
  ]
}
