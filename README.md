## Terraform configs for provisioning homelab resources

### Provisioning

#### Setup tw (terraform wrapper) command

```bash
tw() {
  set -x
  podman run -it --rm --security-opt label=disable \
    -v $HOME/.aws:/root/.aws \
    -v $(pwd):/tf \
    -v /var/cache:/var/cache \
    -w /tf \
    --net=host \
    ghcr.io/randomcoww/tw:latest "$@"
  rc=$?; set +x; return $rc
}
```

### Cleanup

```
tw find ../ -name '*.tf' -exec terraform fmt '{}' \;
```

### Image build

```
mkdir -p build
export TMPDIR=$(pwd)/build

TF_VERSION=1.1.2
LIBVIRT_VERSION=0.1.10
SSH_VERSION=0.1.3

podman build \
  --build-arg TF_VERSION=$TF_VERSION \
  --build-arg LIBVIRT_VERSION=$LIBVIRT_VERSION \
  --build-arg SSH_VERSION=$SSH_VERSION \
  -f Dockerfile \
  -t ghcr.io/randomcoww/tw:latest
```

```
podman push ghcr.io/randomcoww/tw:latest
```