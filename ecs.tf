# -------------------------------------------------------------------
# ECS Cluster
# -------------------------------------------------------------------

resource "aws_ecs_cluster" "uber" {
  name = var.clustername

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_iam_policy" "task_role_logs" {
    name = "UbersystemECSLogs"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup"
                ]
                Resource = "*"
            }
        ]
    })
}

resource "aws_iam_policy" "task_role_ssm" {
  name = "UbersystemECSSSM"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Action": [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_policy" "task_role_secrets" {
  name = "UbersystemECSSecrets"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role" "task_role" {
  name = "UbersystemECSRole"

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
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_role_secrets_attach" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task_role_secrets.arn
}

resource "aws_iam_role_policy_attachment" "task_role_logs_attach" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task_role_logs.arn
}

resource "aws_iam_role_policy_attachment" "task_role_ssm_attach" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task_role_ssm.arn
}

resource "aws_iam_role_policy_attachment" "task_role_default_attach" {
    role = aws_iam_role.task_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -------------------------------------------------------------------
# ECS EC2 Instances
# -------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent" {
  name               = "ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "ecs-agent"
  role = aws_iam_role.ecs_agent.name
}

resource "aws_key_pair" "ecs" {
  key_name   = "uber_ec2_admin"
  public_key = var.ssh_key
}

resource "aws_launch_configuration" "ecs_config_launch_config" {
  name_prefix                 = "${var.clustername}_ecs_cluster"
  image_id                    = data.aws_ami.aws_optimized_ecs.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  lifecycle {
    create_before_destroy = true
  }
  user_data = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${var.clustername} >> /etc/ecs/ecs.config
echo ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true >> /etc/ecs/ecs.config

IFS=","
USERS="${var.ssh_users}"
for USER in $USERS; do
    echo "Adding $USER..."
    adduser -d "/home/$USER" -s /bin/bash -m -G wheel,docker "$USER"
    passwd -u "$USER"
    mkdir -p "/home/$USER/.ssh"
    curl -so "/home/$USER/.ssh/authorized_keys" "https://github.com/$USER.keys"
    chown -R "$USER:$USER" "/home/$USER/.ssh"
    chmod 755 "/home/$USER/.ssh"
    chmod 644 "/home/$USER/.ssh/authorized_keys"
done

echo "%wheel  ALL=(ALL)       NOPASSWD: ALL" > /etc/sudoers.d/wheel
EOF
  security_groups      = [
    aws_security_group.uber_efs_ec2.id
  ]
  key_name             = aws_key_pair.ecs.key_name
  iam_instance_profile = aws_iam_instance_profile.ecs_agent.arn
}

data "aws_ami" "aws_optimized_ecs" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn-ami*amazon-ecs-optimized"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["591542846629"] # AWS
}

resource "aws_ecs_account_setting_default" "account_settings" {
  name  = "awsvpcTrunking"
  value = "enabled"
}

resource "aws_autoscaling_group" "ecs_cluster" {
  name_prefix = "${var.clustername}_asg_"
  termination_policies = [
     "OldestInstance" 
  ]
  default_cooldown          = 30
  health_check_grace_period = 30
  max_size                  = var.max_instances
  min_size                  = var.min_instances
  desired_capacity          = var.desired_capacity
  launch_configuration      = aws_launch_configuration.ecs_config_launch_config.name
  protect_from_scale_in     = false
  lifecycle {
    create_before_destroy = true
  }
  vpc_zone_identifier = [
    aws_subnet.primary.id,
    aws_subnet.secondary.id
  ]
  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ec2_cluster" {
  name = "EC2"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_cluster.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status = "DISABLED"
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "uber_providers" {
  cluster_name = aws_ecs_cluster.uber.name

  capacity_providers = [
    "FARGATE",
    aws_ecs_capacity_provider.ec2_cluster.name
  ]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ec2_cluster.name
  }
}