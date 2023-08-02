locals {
    servers = lookup(yamldecode(file("servers.yaml")), var.environment, {})
    server_names = sort(keys(local.servers))
    paths = zipmap(local.server_names, [
        for server_name in local.server_names: flatten([
            for path in lookup(local.servers, server_name).config_paths: [
                for idx in range(1, length(split("/", path))+1): [
                    for filename in fileset(join("/", slice(split("/", path), 0, idx)), "*.yaml"): join("/", [join("/", slice(split("/", path), 0, idx)), filename])
                ]
            ]
        ])
    ])
}

module "uberserver-ecs" {
    source = "./modules/ubersystem-ecs"
    for_each = local.servers
    providers = {
        curl = curl.ghcr
        postgresql = postgresql
    }

    hostname                = each.value.hostname
    zonename                = each.value.zonename
    private_zone            = lookup(each.value, "private_zone", join("", [each.key,".local"]))
    ubersystem_container    = each.value.ubersystem_container
    lb_priority             = lookup(each.value, "lb_priority", index(local.server_names, each.key))*10+50
    prefix                  = each.value.prefix
    ubersystem_config       = jsonencode([for path in lookup(local.paths, each.key, []): base64gzip(file(path))])
    ubersystem_secrets      = ""
    efs_dir                 = lookup(each.value, "efs_dir", join("", ["/", each.key]))
    uber_db_name            = lookup(each.value, "uber_db_name", each.key)
    uber_db_username        = lookup(each.value, "uber_db_username", each.key)
    launch_type             = lookup(each.value, "launch_type", null)
    health_url              = lookup(each.value, "health_url", "/uber")
    elasticache_id          = aws_elasticache_cluster.uber_redis.id
    rabbitmq_id             = aws_mq_broker.rabbitmq.id
    region                  = var.region

    web_count               = lookup(each.value, "web_count", 1)
    web_cpu                 = lookup(each.value, "web_cpu", 256)
    web_ram                 = lookup(each.value, "web_ram", lookup(each.value, "layout", "scalable") == "single" ? 1580 : 512)
    celery_count            = lookup(each.value, "celery_count", 1)
    celery_cpu              = lookup(each.value, "celery_cpu", 256)
    celery_ram              = lookup(each.value, "celery_ram", 512)

    ecs_cluster             = aws_ecs_cluster.uber.arn
    ecs_task_role           = aws_iam_role.task_role.arn
    subnet_ids              = [
        aws_subnet.primary.id,
        aws_subnet.secondary.id
    ]
    uber_web_securitygroups = [
        aws_security_group.uber_backend.id
    ]
    vpc_id                  = aws_vpc.uber.id
    loadbalancer_arn        = aws_lb.ubersystem.arn
    loadbalancer_dns_name   = aws_lb.ubersystem.dns_name
    lb_web_listener_arn     = aws_lb_listener.ubersystem_web_https.arn
    db_endpoint             = aws_db_instance.uber.endpoint
    efs_id                  = aws_efs_file_system.ubersystem_static.id
}
