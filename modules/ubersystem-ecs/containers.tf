locals {
    container_web = {
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "/ecs/Ubersystem",
                "awslogs-region": "${var.region}",
                "awslogs-stream-prefix": "ecs",
                "awslogs-create-group": "true"
            }
        },
        "portMappings": [
            {
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
                "name": "TESTING",
                "value": "${data.aws_elasticache_cluster.redis.cache_nodes.0.address}"
            },
            {
                "name": "SESSION_HOST",
                "value": "notredis"
            },
            {
                "name": "SESSION_PREFIX",
                "value": var.prefix
            },
            {
                "name": "BROKER_HOST",
                "value": "${data.aws_mq_broker.rabbitmq.id}.mq.${var.region}.amazonaws.com"
            },
            {
                "name": "BROKER_USER",
                "value": var.prefix
            },
            {
                "name": "BROKER_PASS",
                "value": random_password.rabbitmq.result
            },
            {
                "name": "BROKER_VHOST",
                "value": var.prefix
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
        "memoryReservation": 512
    }
    container_celery_beat = {
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "/ecs/Ubersystem",
                "awslogs-region": "${var.region}",
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
                "value": data.aws_mq_broker.rabbitmq.instances.0.ip_address
            },
            {
                "name": "BROKER_USER",
                "value": var.prefix
            },
            {
                "name": "BROKER_PASS",
                "value": random_password.rabbitmq.result
            },
            {
                "name": "BROKER_VHOST",
                "value": var.prefix
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
        "name": "celery-beats",
        "mountPoints": [
            {
                "sourceVolume": "static",
                "containerPath": "/app/plugins/uber/uploaded_files",
                "readOnly": false
            }
        ],
        "memoryReservation": 256
    }
    container_celery_worker = {
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "/ecs/Ubersystem",
                "awslogs-region": "${var.region}",
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
                "value": data.aws_mq_broker.rabbitmq.instances.0.ip_address
            },
            {
                "name": "BROKER_USER",
                "value": var.prefix
            },
            {
                "name": "BROKER_PASS",
                "value": random_password.rabbitmq.result
            },
            {
                "name": "BROKER_VHOST",
                "value": var.prefix
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
        "memoryReservation": 256
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
  name                   = "${var.prefix}_ubersystem_web"
  cluster                = var.ecs_cluster
  task_definition        = aws_ecs_task_definition.ubersystem_web.arn
  desired_count          = var.web_count
  enable_execute_command = true
  launch_type            = var.launch_type

  load_balancer {
    target_group_arn = aws_lb_target_group.ubersystem_http.arn
    container_name   = "web"
    container_port   = 8282
  }
}

resource "aws_ecs_task_definition" "ubersystem_web" {
  family                    = "${var.prefix}_ubersystem_web"
  container_definitions     = jsonencode(
    [
      local.container_web
    ]
  )

  volume {
    name = "static"

    efs_volume_configuration {
      file_system_id          = var.efs_id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.uber.id
      }
    }
  }

  cpu                       = var.web_cpu
  memory                    = var.web_ram
  network_mode              = "bridge"
  execution_role_arn        = var.ecs_task_role

  task_role_arn = var.ecs_task_role
}

# -------------------------------------------------------------------
# MAGFest Ubersystem Containers (celery)
# -------------------------------------------------------------------

resource "aws_ecs_service" "ubersystem_celery_beat" {
  name                   = "${var.prefix}_ubersystem_celery_beat"
  cluster                = var.ecs_cluster
  task_definition        = aws_ecs_task_definition.ubersystem_celery_beat.arn
  desired_count          = 1
  enable_execute_command = true
  launch_type            = var.launch_type
}

resource "aws_ecs_task_definition" "ubersystem_celery_beat" {
  family                    = "${var.prefix}_ubersystem_celery_beat"
  container_definitions     = jsonencode(
    [
      local.container_celery_beat
    ]
  )

  volume {
    name = "static"

    efs_volume_configuration {
      file_system_id          = var.efs_id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.uber.id
      }
    }
  }

  cpu                       = var.celery_cpu
  memory                    = var.celery_ram
  network_mode              = "bridge"
  execution_role_arn        = var.ecs_task_role
  task_role_arn             = var.ecs_task_role
}

resource "aws_ecs_service" "ubersystem_celery_worker" {
  name                   = "${var.prefix}_ubersystem_celery_worker"
  cluster                = var.ecs_cluster
  task_definition        = aws_ecs_task_definition.ubersystem_celery_worker.arn
  desired_count          = var.celery_count
  enable_execute_command = true
  launch_type            = var.launch_type
}

resource "aws_ecs_task_definition" "ubersystem_celery_worker" {
  family                    = "${var.prefix}_ubersystem_celery_worker"
  container_definitions     = jsonencode(
    [
      local.container_celery_worker
    ]
  )

  volume {
    name = "static"

    efs_volume_configuration {
      file_system_id          = var.efs_id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.uber.id
      }
    }
  }

  cpu                       = var.celery_cpu
  memory                    = var.celery_ram
  network_mode              = "bridge"
  execution_role_arn        = var.ecs_task_role
  task_role_arn             = var.ecs_task_role
}
