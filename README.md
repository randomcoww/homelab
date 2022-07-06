## Terraform configs for provisioning homelab resources

### Configure environment

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

[Generate a bootable device for the server](https://github.com/randomcoww/fedora-coreos-config-custom/blob/master/builds/server/README.md)

### Deploy services to kubernetes

```bash
tw terraform -chdir=helm_client \
  apply -var-file=secrets.tfvars
```

### Create PXE boot entry for nodes

Write minio config

```bash
mkdir -p ~/.mc && \
tw terraform -chdir=helm_client output \
  -json minio_endpoint > ~/.mc/config.json
```

---

TODO: Handle minio in terraform

Download minio client `mc`

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
```

Make `boot` bucket

```
mc mb minio/boot
mc policy set download minio/boot
```

---

[Build and upload client image to minio](https://github.com/randomcoww/fedora-coreos-config-custom/blob/master/builds/client/README.md)

Write matchbox PXE boot config

```bash
tw terraform -chdir=pxeboot_config_client apply
```

### Server access

Write admin kubeconfig

```bash
mkdir -p ~/.kube && \
  tw terraform output -raw admin_kubeconfig > ~/.kube/config
```

Sign SSH key

```bash
KEY=$HOME/.ssh/id_ecdsa
tw terraform output -raw ssh_client_cert_authorized_key > $KEY-cert.pub
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
TAG=ghcr.io/randomcoww/tw:latest

buildah build \
  --dns 9.9.9.9 \
  --build-arg TF_VERSION=$TF_VERSION \
  --build-arg SSH_VERSION=$SSH_VERSION \
  --build-arg SYNCTHING_VERSION=$SYNCTHING_VERSION \
  -f Dockerfile \
  -t $TAG && \

buildah push $TAG
```

### Updating helm charts

Full example: https://github.com/technosophos/tscharts

```bash
helm package helm_charts/<chart> -d docs/
helm repo index --url https://randomcoww.github.io/terraform-infra docs/
```

### Container builds

All custom container build Dockerfiles are at https://github.com/randomcoww/container-builds
