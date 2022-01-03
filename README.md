## Terraform configs for provisioning homelab resources

#### Setup tw (terraform wrapper) command

```bash
tw() {
    set -x
    podman run -it --rm --security-opt label=disable \
        -v $HOME/.aws:/root/.aws \
        -v $(pwd):/root/tf \
        -v /var/cache:/var/cache \
        -w /root/tf \
        --net=host \
        ghcr.io/randomcoww/tw:latest "$@"
    rc=$?; set +x; return $rc
}
```