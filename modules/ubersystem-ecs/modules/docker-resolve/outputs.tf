output "docker_digest" {
    value = sha256(data.curl_request.manifest_checksum.response_body)
}

output "image_info" {
    value = local.image_info
}