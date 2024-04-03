terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.38.0"
    }
    postgresql = {
      source = "cyrilgdn/postgresql"
    }
  }
}

# -------------------------------------------------------------------
# Postgres Databases
# -------------------------------------------------------------------

resource "postgresql_database" "uber" {
  name              = var.name
  owner             = var.name
  template          = "template0"
  lc_collate        = "C"
  connection_limit  = -1
  allow_connections = true
  depends_on = [
    postgresql_role.uber
  ]
}

resource "postgresql_schema" "uber_schema" {
  depends_on   = [ postgresql_database.uber ]
  name         = "public"
  database     = var.name
  owner        = var.name
  drop_cascade = true
}

resource "postgresql_role" "uber" {
  name             = var.name
  login            = true
  connection_limit = -1
  password         = aws_secretsmanager_secret_version.password.secret_string
}

resource "random_password" "uber" {
  length            = 40
  special           = false
  keepers           = {
    pass_version  = 2
  }
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.prefix}-rds-passwd"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.uber.result
}
