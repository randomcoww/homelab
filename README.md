## Terraform configs for provisioning homelab resources

### Provisioning

Define the `tw` (terraform wrapper) command

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

### Define secrets

Generate new SSH key (as needed)

```bash
KEY=$HOME/.ssh/id_ecdsa
ssh-keygen -q -t ecdsa -N '' -f $KEY 2>/dev/null <<< y >/dev/null
```

Create `secrets.tfvars` file

```bash
KEY=$HOME/.ssh/id_ecdsa
cat > secrets.tfvars <<EOF
users = {
  admin = {
    password_hash = "$(echo 'password' | mkpasswd -m sha-512 -s)"
  }
  client = {
    password_hash = "$(echo 'password' | mkpasswd -m sha-512 -s)"
  }
}
ssh_client = {
  key_id = "$(whoami)"
  public_key = "ssh_client_public_key=$(cat $KEY.pub)"
  early_renewal_hours = 168
  validity_period_hours = 336
}
wifi = {
  ssid = "ssid"
  passphrase = "passphrase"
}
EOF
```

### Create bootable image for the server

Generate a CoreOS ignition file

```bash
tw terraform apply -var-file=secrets.tfvars
```

[Generate the server image and embed the ignition file](https://github.com/randomcoww/fedora-coreos-config-custom)

### Access kubernetes

Write admin kubeconfig

```bash
mkdir -p ~/.kube && \
  tw terraform output -raw kubeconfig_admin > ~/.kube/config
```

### Create PXE boot entry for client device

This should work once `pxeboot-*` and `metallb` pods are running

```bash
kubectl get pod -A
```

```bash
tw terraform -chdir=pxeboot_config_client apply
```

### Write minio config

```bash
mkdir -p ~/.mc && \
  tw terraform output -json minio_endpoint > ~/.mc/config.json
```

### Sign SSH key for SSH access to server

```bash
KEY=$HOME/.ssh/id_ecdsa
tw terraform output -raw ssh_client_cert_authorized_key > $KEY-cert.pub
```

Libvirt is also accessible via SSH (TODO: Try KubeVirt)

```bash
virsh -c qemu+ssh://fcos@aio-0.local/system list --all
```

### Cleanup terraform file formatting for checkin

```bash
tw find . -name '*.tf' -exec terraform fmt '{}' \;
```

### Build terrafrom wrapper image

```bash
TF_VERSION=1.1.2
SSH_VERSION=0.1.4
SYNCTHING_VERSION=0.1.2

buildah build \
  --build-arg TF_VERSION=$TF_VERSION \
  --build-arg SSH_VERSION=$SSH_VERSION \
  --build-arg SYNCTHING_VERSION=$SYNCTHING_VERSION \
  -f Dockerfile \
  -t ghcr.io/randomcoww/tw:latest
```

```bash
buildah push ghcr.io/randomcoww/tw:latest
```