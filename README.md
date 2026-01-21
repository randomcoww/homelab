## Terraform (OpenTofu) provisioner for Kubernetes homelab

Run Terraform in container (optional).

```bash
tofu() {
  set -x
  podman run -it --rm --security-opt label=disable \
    -v $(pwd):$(pwd) \
    -w $(pwd) \
    --env-file=credentials.env \
    --net=host \
    ghcr.io/opentofu/opentofu:latest "$@"
  rc=$?; set +x; return $rc
}
```

* [Initial host provisioning](./docs/provisioning.md)

* [Kubernetes and host maintenance](./docs/maintenance.md)
