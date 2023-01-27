module "stock2023" {
    source = "github.com/magfest/terraform-aws-ubersystem-ecs"
    ecs_cluster             = aws_ecs_cluster.uber.arn
    ecs_task_role           = aws_iam_role.task_role.arn
    subnet_ids              = [
        aws_subnet.primary.id,
        aws_subnet.secondary.id
    ]
    uber_web_securitygroups = [
        aws_security_group.uber_backend.arn
    ]
    rabbitmq_securitygroups = [
        aws_security_group.uber_rabbitmq.arn
    ]
    redis_securitygroups    = [
        aws_security_group.uber_redis.arn
    ]
    vpc_id                  = aws_vpc.uber.id
    hostname                = "stock2023.dev.magevent.net"
    zonename                = var.zonename
    ubersystem_container    = "ghcr.io/magfest/magprime:main"
    loadbalancer_arn        = aws_lb.ubersystem.arn
    lb_web_listener_arn     = aws_lb_listener.ubersystem_web_https.arn
    lb_priority             = 10
    prefix                  = "stck23"
    event                   = "stock"
    year                    = "2023"
    environment             = "prod"
    db_endpoint             = aws_db_instance.uber.endpoint
    db_username             = aws_db_instance.uber.username
    db_password             = aws_secretsmanager_secret_version.password.secret_string
    rds_instance            = [
        aws_db_instance.endpoint
    ]
    uber_db_name            = "stock2023"
    uber_db_username        = "stock2023"
}