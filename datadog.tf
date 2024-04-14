# Docs: https://aws.amazon.com/blogs/mt/packaging-to-distribution-using-aws-systems-manager-distributor-to-deploy-datadog/

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
            "DD_API_KEY=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.datadog_api_key.name}) DD_SITE="datadoghq.com" bash -c \"$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)\""
          ]
        }
      }
    ]
  }
  EOF

  depends_on = [ aws_secretsmanager_secret_version.datadog_api_key ]
  count = var.datadog_api_key != null ? 0 : 1
}

resource "aws_secretsmanager_secret" "datadog_api_key" {
  name_prefix = "datadog-"

  count = var.datadog_api_key != null ? 0 : 1
}

resource "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id     = aws_secretsmanager_secret.datadog_api_key.id
  secret_string = var.datadog_api_key

  count = var.datadog_api_key != null ? 0 : 1
}
