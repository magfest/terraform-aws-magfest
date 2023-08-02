resource "aws_security_group" "uber_rabbitmq" {
  name        = "uber_rabbitmq"
  description = "Allow Uber to reach RabbitMQ"
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

resource "aws_mq_broker" "rabbitmq" {
  broker_name = "uber"

  engine_type         = "RabbitMQ"
  engine_version      = "3.11.16"
  host_instance_type  = "mq.t3.micro"
  #security_groups     = [aws_security_group.uber_rabbitmq.id]
  subnet_ids          = [aws_subnet.primary.id]
  publicly_accessible = true

  user {
    username = "admin"
    password = random_password.rabbitmq.result
  }
}

resource "random_password" "rabbitmq" {
  length            = 40
  special           = false
  keepers           = {
    pass_version  = 2
  }
}

resource "aws_secretsmanager_secret" "rabbitmq_password" {
  name = "rabbitmq-passwd"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rabbitmq_password" {
  secret_id = aws_secretsmanager_secret.rabbitmq_password.id
  secret_string = random_password.rabbitmq.result
}

provider "rabbitmq" {
  endpoint = aws_mq_broker.rabbitmq.instances.0.endpoints.0
  username = "admin"
  password = random_password.rabbitmq.result
}