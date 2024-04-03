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
  name                    = "${var.name}-rds-passwd"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.uber.result
}


moved {
  from = module.uberserver-ecs.postgresql_database.uber
  to = module.postgres-db.postgresql_database.uber
}

moved {
  from = module.uberserver-ecs.postgresql_schema.uber_schema
  to = module.postgres-db.postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs.postgresql_role.uber
  to = module.postgres-db.postgresql_role.uber
}

moved {
  from = module.uberserver-ecs.random_password.uber
  to = module.postgres-db.random_password.uber
}

moved {
  from = module.uberserver-ecs.aws_secretsmanager_secret.db_password
  to = module.postgres-db.aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs.aws_secretsmanager_secret_version.password
  to = module.postgres-db.aws_secretsmanager_secret_version.password
}

