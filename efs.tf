# -------------------------------------------------------------------
# Elastic File System
# -------------------------------------------------------------------

resource "aws_security_group" "uber_efs" {
  name        = "uber_efs"
  description = "Allow access to EFS"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "EFS"
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = [
        aws_subnet.primary.cidr_block,
        aws_subnet.secondary.cidr_block
    ]
  }

  ingress {
    description      = "EFS Encryption"
    from_port        = 1
    to_port          = 65535
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
    Name = "Ubersystem EFS"
  }
}

resource "aws_security_group" "uber_efs_ec2" {
  name        = "uber_efs_ec2"
  description = "Allow access to instances in EC2 ECS nodes"
  vpc_id      = aws_vpc.uber.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [
        "0.0.0.0/0"
    ]
  }

  ingress {
    description      = "Internal"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
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
    Name = "Ubersystem ECS EC2"
  }
}

resource "aws_efs_file_system" "ubersystem_static" {
  creation_token = "ubersystem"

  tags = {
    Name = "Ubersystem"
  }
}

resource "aws_efs_mount_target" "primary" {
  file_system_id  = aws_efs_file_system.ubersystem_static.id
  subnet_id       = aws_subnet.primary.id
  security_groups = [
    aws_security_group.uber_efs.id
  ]
}

resource "aws_efs_mount_target" "secondary" {
  file_system_id  = aws_efs_file_system.ubersystem_static.id
  subnet_id       = aws_subnet.secondary.id
  security_groups = [
    aws_security_group.uber_efs.id
  ]
}