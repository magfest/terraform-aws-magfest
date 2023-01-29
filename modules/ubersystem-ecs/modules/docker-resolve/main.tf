terraform {
  required_providers {
    curl = {
      source = "marcofranssen/curl"
    }
  }
}

locals {
    image_info = regex("^(?:(?P<hostname>(?:[a-z0-9]+\\.)+[a-z0-9]+)(?::(?P<port>[0-9]+))?/)?(?P<path>(?:[a-z0-9]+/)*[a-z0-9]+)(?::(?P<tag>[a-z0-9\\.]+))?(?:@sha256:(?P<hash>[a-f0-9]+))?$", var.image)
    reference = local.image_info.hash != null ? local.image_info.hash : local.image_info.tag != null ? local.image_info.tag : "latest"
}

data "curl_request" "manifest_checksum" {
    http_method = "GET"
    uri = "https://${local.image_info.hostname}/v2/${local.image_info.path}/manifests/${local.reference}"
    lifecycle {
        postcondition {
          condition = self.response_status_code == 200
          error_message = "Invalid response code getting image sha256sum: ${self.response_status_code}\n\n${self.response_body}"
        }
    }
}