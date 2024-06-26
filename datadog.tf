# Docs: https://aws.amazon.com/blogs/mt/packaging-to-distribution-using-aws-systems-manager-distributor-to-deploy-datadog/

resource "aws_ssm_association" "datadog_install" {
  name = aws_ssm_document.datadog_install[0].name

  targets {
    key    = "tag:aws:autoscaling:groupName"
    values = [ aws_autoscaling_group.ecs_cluster.name ]
  }

  count = var.datadog_api_key != null ? 1 : 0
}

resource "aws_ssm_document" "datadog_install" {
  name          = "DatadogInstall"
  document_type = "Command"
  content = <<EOF
  {
    "schemaVersion": "2.2",
    "description": "Install the Datadog Agent",
    "mainSteps": [
      {
        "action": "aws:runShellScript",
        "name": "install",
        "inputs": {
          "runCommand": [ 
            "DD_API_KEY=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.datadog_api_key[0].name} --query SecretString --output text) DD_SITE=\"datadoghq.com\" DD_LOGS_ENABLED=true DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true DD_APM_INSTRUMENTATION_ENABLED=host DD_APM_INSTRUMENTATION_LIBRARIES=\"python\" DD_ENV=\"${var.environment}\" bash -c \"$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)\"",
            "sudo usermod -a -G docker dd-agent"
          ]
        }
      }
    ]
  }
  EOF

  depends_on = [ aws_secretsmanager_secret_version.datadog_api_key[0] ]
  count = var.datadog_api_key != null ? 1 : 0
}

resource "aws_secretsmanager_secret" "datadog_api_key" {
  name_prefix = "datadog-"

  count = var.datadog_api_key != null ? 1 : 0
}

resource "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id     = aws_secretsmanager_secret.datadog_api_key[0].id
  secret_string = var.datadog_api_key

  count = var.datadog_api_key != null ? 1 : 0
}
