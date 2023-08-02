variable "hostname" {
    type    = string
    default = "dev.magevent.net"
}

variable "zonename" {
    type    = string
    default = "dev.magevent.net"
}

variable "environment" {
    type    = string
    default = "staging"
}

variable "clustername" {
    type    = string
    default = "Ubersystem"
}

variable "instance_type" {
    type    = string
    default = "t3.medium"
}

variable "desired_capacity" {
    type    = number
    default = 1
}

variable "max_instances" {
    type    = number
    default = 5
}

variable "min_instances" {
    type    = number
    default = 1
}

variable "ssh_key" {
    type    = string
}

variable "ssh_users" {
    type    = string
}

variable "cidr_block" {
    type    = string
    default = "10.0.0.0/16"
}

variable "region" {
    type    = string
    default = "us-east-1"
}