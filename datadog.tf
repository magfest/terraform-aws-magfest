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
            "DD_API_KEY=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.datadog_api_key[0].name}) DD_SITE=\"datadoghq.com\" bash -c \"$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)\""
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
