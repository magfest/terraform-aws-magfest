# -------------------------------------------------------------------
# RDS
# -------------------------------------------------------------------

locals {
    servers = lookup(yamldecode(file("databases.yaml")), var.environment, [])
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
  instance_class         = var.rds_instance_size
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

# -------------------------------------------------------------------
# Postgres Databases
# -------------------------------------------------------------------

resource "postgresql_database" "uber" {
  for_each          = local.servers
  name              = each.key
  owner             = each.key
  template          = "template0"
  lc_collate        = "C"
  connection_limit  = -1
  allow_connections = true
  depends_on = [
    postgresql_role.uber[each.key]
  ]
}

resource "postgresql_schema" "uber_schema" {
  for_each     = local.servers
  depends_on   = [ postgresql_database.uber[each.key] ]
  name         = "public"
  database     = each.key
  owner        = each.key
  drop_cascade = true
}

resource "postgresql_role" "uber" {
  for_each         = local.servers
  name             = each.key
  login            = true
  connection_limit = -1
  password         = aws_secretsmanager_secret_version.password[each.key].secret_string
}

resource "random_password" "uber" {
  for_each          = local.servers
  length            = 40
  special           = false
  keepers           = {
    pass_version  = 2
  }
}

resource "aws_secretsmanager_secret" "db_password" {
  for_each                = local.servers
  name                    = "${each.key}-rds-passwd"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "password" {
  for_each      = local.servers
  secret_id     = aws_secretsmanager_secret.db_password[each.key].id
  secret_string = random_password.uber[each.key].result
}