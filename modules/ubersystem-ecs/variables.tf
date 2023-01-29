variable "ecs_cluster" {
    type    = string
}

variable "ecs_task_role" {
    type    = string
}

variable "subnet_ids" {
    type    = list(string)
}

variable "uber_web_securitygroups" {
    type    = list(string)
}

variable "rabbitmq_securitygroups" {
    type    = list(string)
}

variable "redis_securitygroups" {
    type    = list(string)
}

variable "vpc_id" {
    type    = string
}

variable "hostname" {
    type    = string
}

variable "zonename" {
    type    = string
}

variable "ubersystem_container" {
    type    = string

    default = "ghcr.io/magfest/magprime:main"
}

variable "web_cpu" {
    type = number
    default = 256
}

variable "web_ram" {
    type = number
    default = 512
}

variable "loadbalancer_arn" {
    type    = string
}

variable "loadbalancer_dns_name" {
    type    = string
}

variable "lb_web_listener_arn" {
    type    = string
}

variable "lb_priority" {
    type    = number
}

variable "prefix" {
    type    = string
    default = "uber"
}

variable "ubersystem_config" {
    type    = string
}

variable "ubersystem_secrets" {
    type    = string
}

variable "db_endpoint" {
    type    = string
}

variable "uber_db_name" {
    type    = string
}

variable "uber_db_username" {
    type    = string
}

variable "efs_id" {
    type    = string
}

variable "efs_dir" {
    type    = string
}