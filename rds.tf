# -------------------------------------------------------------------
# RDS
# -------------------------------------------------------------------

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
    Name = "Ubersystem RDS"
  }
}

resource "random_password" "uber" {
  length            = 40
  special           = false
  keepers           = {
    pass_version  = 2
  }
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "rds-postgres-passwd"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.uber.result
}

resource "aws_db_instance" "uber" {
  allocated_storage      = 100
  storage_type           = "gp3"
  db_name                = "uber"
  engine                 = "postgres"
  instance_class         = "db.m5d.4xlarge"
  identifier             = "ubersystem"
  username               = "postgres"
  password               = aws_secretsmanager_secret_version.password.secret_string
  skip_final_snapshot    = true
  multi_az               = false
  publicly_accessible    = true
  vpc_security_group_ids = [
    aws_security_group.uber_rds.id
  ]
  db_subnet_group_name   = aws_db_subnet_group.uber.name
  depends_on = [
    aws_route_table_association.primary_route,
    aws_route_table_association.secondary_route
  ]
}

provider "postgresql" {
  host       = aws_db_instance.uber.address
  username   = aws_db_instance.uber.username
  password   = aws_secretsmanager_secret_version.password.secret_string
  superuser  = false
}