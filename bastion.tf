# -------------------------------------------------------------------
# SSH Bastion Server
# -------------------------------------------------------------------

resource "aws_efs_access_point" "bastion" {
  file_system_id = aws_efs_file_system.ubersystem_static.id

  root_directory {
    path = "/"
    creation_info {
      owner_gid   = 65534
      owner_uid   = 65534
      permissions = 0755
    }
  }

  tags = {
    Name = "bastion"
  }
}

resource "aws_ecs_task_definition" "ssh_bastion" {
  family                    = "ssh_bastion"
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
            "hostPort": 22,
            "protocol": "tcp",
            "containerPort": 22
          }
        ],
        "environment": [
          {
            "name": "USERS",
            "value": "bitbyt3r,kitsuta"
          }
        ],
        "image": "ghcr.io/magfest/bastion-ecs:main",
        "essential": true,
        "name": "bastion",
        "mountPoints": [
          {
            "sourceVolume": "ubersystem",
            "containerPath": "/efs",
            "readOnly": false
          }
        ]
      }
    ]
  )

  volume {
    name = "ubersystem"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.ubersystem_static.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.bastion.id
      }
    }
  }

  cpu                       = 256
  memory                    = 512
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  execution_role_arn        = aws_iam_role.task_role.arn

  task_role_arn = aws_iam_role.task_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_security_group" "bastion_ssh" {
  name        = "bastion_ssh"
  description = "Allow SSH to the bastion instance"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "SSH to Bastion"
    from_port        = 22
    to_port          = 22
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
    Name = "Bastion SSH"
  }
}

resource "aws_ecs_service" "ssh" {
  name            = "bastion_ssh"
  cluster         = aws_ecs_cluster.uber.arn
  task_definition = aws_ecs_task_definition.ssh_bastion.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets           = [
        aws_subnet.primary.id,
        aws_subnet.secondary.id
    ]
    security_groups   = [
        aws_security_group.bastion_ssh.id
    ]
    assign_public_ip  = true
  }
  
  service_registries {
    registry_arn = aws_service_discovery_service.bastion.arn
  }
}

resource "aws_service_discovery_public_dns_namespace" "bastion" {
  name        = "bastion.dev.magevent.net"
  description = "bastion host namespace"
}

resource "aws_service_discovery_service" "bastion" {
  name = "ssh"

  dns_config {
    namespace_id = aws_service_discovery_public_dns_namespace.bastion.id

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