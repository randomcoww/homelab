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

### Define secrets

#### Generate SSH key as needed

```
KEY=$HOME/.ssh/id_ecdsa
ssh-keygen -q -t ecdsa -N '' -f $KEY 2>/dev/null <<< y >/dev/null
```

#### Update secrets file

```
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
EOF
```

### Run

```
tw terraform apply -var-file=secrets.tfvars
```

### Sign local SSH key

```
KEY=$HOME/.ssh/id_ecdsa
tw terraform output -raw ssh_client_cert_authorized_key > $KEY-cert.pub
```

#### Hit libvirt over SSH

```
virsh -c qemu+ssh://fcos@hypervisor-0.local/system list --all
```

### Write admin kubeconfig

```
mkdir -p ~/.kube && \
  tw terraform output -raw kubeconfig_admin > ~/.kube/config
```

### Cleanup

```
tw find . -name '*.tf' -exec terraform fmt '{}' \;
```

### Hypervisor

TODO: Try KubeVirt

```
virsh -c qemu+ssh://fcos@aio-0.local/system list --all

```

### Image build

```
TF_VERSION=1.1.2
LIBVIRT_VERSION=0.1.10
SSH_VERSION=0.1.3

buildah build \
  --build-arg TF_VERSION=$TF_VERSION \
  --build-arg LIBVIRT_VERSION=$LIBVIRT_VERSION \
  --build-arg SSH_VERSION=$SSH_VERSION \
  -f Dockerfile \
  -t ghcr.io/randomcoww/tw:latest
```

```
buildah push ghcr.io/randomcoww/tw:latest
```