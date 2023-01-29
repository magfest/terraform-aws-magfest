# Terraform Docker Resolve

Uses curl to resolve a docker tag to it's digest without requiring a local docker daemon.

Currently only supports public ghcr.io images.

## Variables

### image

Accepts a docker image reference as a string. For example:

* ghcr.io/magfest/magprime:main
* ghcr.io/magfest/magprime:main@sha256:ec2816ba79cfdf3226f40013816c702fe14de6b99fdd957acccbe3635ec43373

## Outputs

### docker_digest

The bare checksum of the resolved image tag. For example:
`ec2816ba79cfdf3226f40013816c702fe14de6b99fdd957acccbe3635ec43373`

### image_info

An object with the following keys:

* hostname - The repository hostname. Currently this must be ghcr.io
* port - The port the repository is running on.
* path - The image path under the repository, i.e. magfest/magprime
* tag - The image tag, if provided.
* hash - The bare hash provided in docker_digest (which should match docker_digest)