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
  cloud {
    organization = "magfest"
    workspaces {
      name = "ubersystem-staging"
    }
  }
}

# -------------------------------------------------------------------
# VPC
# -------------------------------------------------------------------

resource "aws_vpc" "uber" {
  cidr_block = var.cidr_block
  enable_dns_hostnames = true
  
  tags = {
    Name = "Ubersystem"
  }
}

# -------------------------------------------------------------------
# Subnets
# -------------------------------------------------------------------

resource "aws_subnet" "primary" {
  vpc_id                  = aws_vpc.uber.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, 0)
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "Ubersystem Primary"
  }
}

resource "aws_subnet" "secondary" {
  vpc_id                  = aws_vpc.uber.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, 1)
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Ubersystem Secondary"
  }
}

resource "aws_db_subnet_group" "uber" {
  name       = "uber"
  subnet_ids = [
    aws_subnet.primary.id,
    aws_subnet.secondary.id
  ]

  tags = {
    Name = "Ubersystem"
  }
}

# -------------------------------------------------------------------
# Routes and Gateways
# -------------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.uber.id

  tags = {
    Name = "Ubersystem"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.uber.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.igw.id}"
  }
  
  tags = {
    Name = "Ubersystem"
  }
}

resource "aws_route_table_association" "primary_route" {
  subnet_id      = aws_subnet.primary.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "secondary_route" {
  subnet_id      = aws_subnet.secondary.id
  route_table_id = aws_route_table.public.id
}

data "curl_request" "ghcr_token" {
  http_method = "GET"
  uri = "https://ghcr.io/token?scope=repository:magfest/magprime:pull"
  lifecycle {
    postcondition {
      condition = self.response_status_code == 200
      error_message = "Invalid response code getting login token: ${self.response_status_code}\n\n${self.response_body}"
    }
  }
}

provider "curl" {
  alias = "ghcr"
  token = jsondecode(data.curl_request.ghcr_token.response_body).token
}

moved {
  from = module.uberserver-ecs["super"].postgresql_database.uber
  to = module.postgres-db["super"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["super"].postgresql_schema.uber_schema
  to = module.postgres-db["super"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["super"].postgresql_role.uber
  to = module.postgres-db["super"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["super"].random_password.uber
  to = module.postgres-db["super"].random_password.uber
}

moved {
  from = module.uberserver-ecs["super"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["super"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["super"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["super"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["stock"].postgresql_database.uber
  to = module.postgres-db["stock"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["stock"].postgresql_schema.uber_schema
  to = module.postgres-db["stock"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["stock"].postgresql_role.uber
  to = module.postgres-db["stock"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["stock"].random_password.uber
  to = module.postgres-db["stock"].random_password.uber
}

moved {
  from = module.uberserver-ecs["stock"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["stock"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["stock"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["stock"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["west"].postgresql_database.uber
  to = module.postgres-db["west"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["west"].postgresql_schema.uber_schema
  to = module.postgres-db["west"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["west"].postgresql_role.uber
  to = module.postgres-db["west"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["west"].random_password.uber
  to = module.postgres-db["west"].random_password.uber
}

moved {
  from = module.uberserver-ecs["west"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["west"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["west"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["west"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["super2023"].postgresql_database.uber
  to = module.postgres-db["super2023"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["super2023"].postgresql_schema.uber_schema
  to = module.postgres-db["super2023"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["super2023"].postgresql_role.uber
  to = module.postgres-db["super2023"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["super2023"].random_password.uber
  to = module.postgres-db["super2023"].random_password.uber
}

moved {
  from = module.uberserver-ecs["super2023"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["super2023"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["super2023"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["super2023"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["stock2024"].postgresql_database.uber
  to = module.postgres-db["stock2024"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["stock2024"].postgresql_schema.uber_schema
  to = module.postgres-db["stock2024"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["stock2024"].postgresql_role.uber
  to = module.postgres-db["stock2024"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["stock2024"].random_password.uber
  to = module.postgres-db["stock2024"].random_password.uber
}

moved {
  from = module.uberserver-ecs["stock2024"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["stock2024"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["stock2024"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["stock2024"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["super2024"].postgresql_database.uber
  to = module.postgres-db["super2024"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["super2024"].postgresql_schema.uber_schema
  to = module.postgres-db["super2024"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["super2024"].postgresql_role.uber
  to = module.postgres-db["super2024"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["super2024"].random_password.uber
  to = module.postgres-db["super2024"].random_password.uber
}

moved {
  from = module.uberserver-ecs["super2024"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["super2024"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["super2024"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["super2024"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["super2023"].postgresql_database.uber
  to = module.postgres-db["super2023"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["super2023"].postgresql_schema.uber_schema
  to = module.postgres-db["super2023"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["super2023"].postgresql_role.uber
  to = module.postgres-db["super2023"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["super2023"].random_password.uber
  to = module.postgres-db["super2023"].random_password.uber
}

moved {
  from = module.uberserver-ecs["super2023"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["super2023"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["super2023"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["super2023"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["stock2023"].postgresql_database.uber
  to = module.postgres-db["stock2023"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["stock2023"].postgresql_schema.uber_schema
  to = module.postgres-db["stock2023"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["stock2023"].postgresql_role.uber
  to = module.postgres-db["stock2023"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["stock2023"].random_password.uber
  to = module.postgres-db["stock2023"].random_password.uber
}

moved {
  from = module.uberserver-ecs["stock2023"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["stock2023"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["stock2023"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["stock2023"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["west2023"].postgresql_database.uber
  to = module.postgres-db["west2023"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["west2023"].postgresql_schema.uber_schema
  to = module.postgres-db["west2023"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["west2023"].postgresql_role.uber
  to = module.postgres-db["west2023"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["west2023"].random_password.uber
  to = module.postgres-db["west2023"].random_password.uber
}

moved {
  from = module.uberserver-ecs["west2023"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["west2023"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["west2023"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["west2023"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["super2022"].postgresql_database.uber
  to = module.postgres-db["super2022"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["super2022"].postgresql_schema.uber_schema
  to = module.postgres-db["super2022"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["super2022"].postgresql_role.uber
  to = module.postgres-db["super2022"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["super2022"].random_password.uber
  to = module.postgres-db["super2022"].random_password.uber
}

moved {
  from = module.uberserver-ecs["super2022"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["super2022"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["super2022"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["super2022"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["super2020"].postgresql_database.uber
  to = module.postgres-db["super2020"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["super2020"].postgresql_schema.uber_schema
  to = module.postgres-db["super2020"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["super2020"].postgresql_role.uber
  to = module.postgres-db["super2020"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["super2020"].random_password.uber
  to = module.postgres-db["super2020"].random_password.uber
}

moved {
  from = module.uberserver-ecs["super2020"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["super2020"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["super2020"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["super2020"].aws_secretsmanager_secret_version.password
}


moved {
  from = module.uberserver-ecs["west2022"].postgresql_database.uber
  to = module.postgres-db["west2022"].postgresql_database.uber
}

moved {
  from = module.uberserver-ecs["west2022"].postgresql_schema.uber_schema
  to = module.postgres-db["west2022"].postgresql_schema.uber_schema
}

moved {
  from = module.uberserver-ecs["west2022"].postgresql_role.uber
  to = module.postgres-db["west2022"].postgresql_role.uber
}

moved {
  from = module.uberserver-ecs["west2022"].random_password.uber
  to = module.postgres-db["west2022"].random_password.uber
}

moved {
  from = module.uberserver-ecs["west2022"].aws_secretsmanager_secret.db_password
  to = module.postgres-db["west2022"].aws_secretsmanager_secret.db_password
}

moved {
  from = module.uberserver-ecs["west2022"].aws_secretsmanager_secret_version.password
  to = module.postgres-db["west2022"].aws_secretsmanager_secret_version.password
}