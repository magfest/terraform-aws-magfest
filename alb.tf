# -------------------------------------------------------------------
# Load Balancer
# -------------------------------------------------------------------

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "uber_backend" {
  name        = "uber_backend"
  description = "Allow ALB to reach Uber"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "HTTP to Ubersystem Web"
    from_port        = 8282
    to_port          = 8282
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
    Name = "Ubersystem Backend"
  }
}

resource "aws_security_group" "uber_public" {
  name        = "uber_public"
  description = "Allow Cloudfront to reach Uber"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "Ubersystem HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    prefix_list_ids  = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Ubersystem Public"
  }
}

resource "aws_security_group" "uber_internal" {
  name        = "uber_internal"
  description = "Allow Uber to reach Uber"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "Ubersystem HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups = [aws_security_group.uber_efs_ec2.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Ubersystem Internal"
  }
}

resource "aws_lb" "ubersystem" {
  name               = "Ubersystem"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [
    aws_security_group.uber_public.id,
    aws_security_group.uber_internal.id
  ]
  subnets            = [
    aws_subnet.primary.id,
    aws_subnet.secondary.id
  ]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "ubersystem_web_http" {
  load_balancer_arn = aws_lb.ubersystem.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Unknown ubersystem endpoint"
      status_code  = "404"
    }
  }
}
