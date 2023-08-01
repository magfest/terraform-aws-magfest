resource "aws_security_group" "uber_redis" {
  name        = "uber_redis"
  description = "Allow Ubersystem to reach Redis"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "Ubersystem Redis"
    from_port        = 6379
    to_port          = 6379
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
    Name = "Ubersystem Redis"
  }
}

resource "aws_elasticache_subnet_group" "uber_subnets" {
  name       = "uber"
  subnet_ids = [
    aws_subnet.primary.id,
    aws_subnet.secondary.id
  ]
}

resource "aws_elasticache_cluster" "uber_redis" {
  cluster_id           = "uber"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  security_group_ids   = [aws_security_group.uber_redis.id]
  subnet_group_name    = aws_elasticache_subnet_group.uber_subnets.name
}