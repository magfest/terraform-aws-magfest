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
    default = "t3.nano"
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