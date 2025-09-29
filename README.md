## Terraform provisioner for Kubernetes homelab

Run Terraform in container (optional).

```bash
terraform() {
  set -x
  podman run -it --rm --security-opt label=disable \
    -v $(pwd):$(pwd) \
    -w $(pwd) \
    --env-file=credentials.env \
    --net=host \
    docker.io/hashicorp/terraform:latest "$@"
  rc=$?; set +x; return $rc
}
```

* [Host provisioning](./docs/provisioning.md)

* [Kubernetes provisioning and maintenance](./docs/maintenance.md)