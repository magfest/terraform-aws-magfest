terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.15.0"
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
