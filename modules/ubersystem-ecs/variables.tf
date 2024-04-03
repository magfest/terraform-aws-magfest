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

variable "vpc_id" {
    type    = string
}

variable "hostname" {
    type    = string
}

variable "zonename" {
    type    = string
}

variable "private_zone" {
    type    = string
}

variable "ubersystem_container" {
    type    = string

    default = "ghcr.io/magfest/magprime:main"
}

variable "web_cpu" {
    type = number
    default = 256
    nullable = true
}

variable "web_ram" {
    type = number
    default = 256
    nullable = true
}

variable "web_count" {
  type = number
  default = 1
}

variable "celery_cpu" {
    type = number
    default = 384
    nullable = true
}

variable "celery_ram" {
    type = number
    default = 768
    nullable = true
}

variable "celery_beat_cpu" {
    type = number
    default = 128
    nullable = true
}

variable "celery_beat_ram" {
    type = number
    default = 256
    nullable = true
}

variable "celery_count" {
  type = number
  default = 1
}

variable "enable_celery" {
    type    = bool
    default = true
}

variable "loadbalancer_arn" {
    type    = string
}

variable "loadbalancer_dns_name" {
    type    = string
}

variable "cloudfront_dns_name" {
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

variable "uber_db_password" {
    type    = string
}

variable "efs_id" {
    type    = string
}

variable "efs_dir" {
    type    = string
}

variable "health_url" {
    type    = string
    default = "/uber/devtools/health"
}

variable "region" {
    type    = string
}

variable "redis_sg_id" {
    type    = string
}

variable "redis_subnet_group_name" {
    type    = string
}