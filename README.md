## Provisioning

### Environment

#### Define the `tw` (terraform wrapper) command

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

```bash
KEY=$HOME/.ssh/id_ecdsa
ssh-keygen -q -t ecdsa -N '' -f $KEY 2>/dev/null <<< y >/dev/null
```

#### Create `secrets.tfvars` file

Reference: [Authelia user password generation](https://www.authelia.com/reference/guides/passwords/#user--password-file)

```bash
KEY=$HOME/.ssh/id_ecdsa
cat > secrets.tfvars <<EOF
# System users
users = {
  admin = {}
  client = {
    password_hash = "$(echo 'password' | mkpasswd -m sha-512 -s)"
  }
}

# System SSH CA signing
ssh_client = {
  key_id = "$(whoami)"
  public_key = "ssh_client_public_key=$(cat $KEY.pub)"
  early_renewal_hours = 168
  validity_period_hours = 336
}

# Hostapd users
wifi = {
  ssid = "ssid"
  passphrase = "passphrase"
}

# Cert-manager letsencrypt profile
letsencrypt_email = "user@domain"

# Service SSO users
authelia_users = {
  username = {
    displayname = "John Smith"
    email = "user@domain"
    password = "$(podman run docker.io/authelia/authelia:latest authelia hash-password -- 'password' | sed 's:.*\: ::')"
    groups = []
  }
}

wireguard_client = {
  Interface = {
    PrivateKey = ""
    Address = ""
    DNS = ""
  }
  Peer = {
    PublicKey = ""
    AllowedIPs = ""
    Endpoint = ""
  }
}
EOF
```

### Create bootable OS images

#### Generate CoreOS ignition for all nodes

```bash
tw terraform -chdir=ignition_config \
  apply -var-file=secrets.tfvars
```

#### Create custom CoreOS images

See [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom/blob/master/builds/server/README.md)

Embed the ignition files generated above into the image to allow them to boot configured

### Deploy services to kubernetes

#### Write admin kubeconfig

```bash
mkdir -p ~/.kube && \
tw terraform -chdir=ignition_config \
  output -raw admin_kubeconfig > ~/.kube/config
```

#### Check that `kubernetes` service is up

```bash
kubectl get svc
```

#### Once Kubernetes is up deploy helm charts

```bash
tw terraform -chdir=helm_client \
  apply -var-file=secrets.tfvars
```

This will provision services used in following steps

### Create PXE boot entry for nodes

#### Prepare minio client

Download `mc`

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
```

Write configuration for `mc`

```bash
mkdir -p ~/.mc && \
tw terraform -chdir=helm_client \
  output -json minio_endpoint > ~/.mc/config.json
```

#### Create and configure buckets

TODO: Handle this in terraform or helm

Check that minio pods are running

```bash
kubectl get po -l app=minio
```

Once pods are running make the `boot` bucket for holding PXE boot images

```
mc mb minio/boot
mc policy set download minio/boot
```

#### Push OS images generated previously into Minio

See [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom/blob/master/builds/server/README.md)

#### Write matchbox PXE boot config

Update image tags [here](https://github.com/randomcoww/terraform-infra/blob/master/config_pxeboot.tf#L2) with those pushed in previous step

Check that matchbox pods are running

```bash
kubectl get po -l app=matchbox
```

Once pods are running write PXE boot configuration for all nodes to matchbox

```bash
tw terraform -chdir=pxeboot_config_client apply
```

Each node may be PXE booted now and boot disks are no longer needed as long as two or more nodes are running

#### Desktop VM with GPU passthrough

Enable a combination of the following `boot_args` in [PXE boot params](config_pxeboot.tf).

Delect and stub all Nvidia GPUs:

```
vfio-pci.ids=10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff
```

Delect and stub all AMD GPUs:

```
vfio-pci.ids=1002:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,1002:ffffffff:ffffffff:ffffffff:00040300:ffffffff
```

Update the following evdev input devices in [the passthrough libvirt config](libvirt/de-1-pt.xml) to match current hardware.

```xml
<devices>
  <input type='evdev'>
    <source dev='/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse'/>
  </input>
  <input type='evdev'>
    <source dev='/dev/input/by-id/usb-MOSART_Semi._wireless_dongle-event-kbd' grab='all' repeat='on'/>
  </input>
</devices>
```

Define and launch. This will produce no video unless a display is attached to the GPU being passed through.

```bash
virsh define libvirt/de-1-pt.xml
virsh start de-1-pt
```

## Maintenance

### Server access

#### Sign SSH key

This is valid for `validity_period_hours` as configured in `secrets.tfvars`

```bash
KEY=$HOME/.ssh/id_ecdsa
tw terraform -chdir=ignition_config \
  output -raw ssh_client_cert_authorized_key > $KEY-cert.pub
```

### Updating helm charts

Full example: https://github.com/technosophos/tscharts

```bash
helm package helm_charts/<chart> -d docs/
helm repo index --url https://randomcoww.github.io/terraform-infra docs/
```

New chart should appear in https://randomcoww.github.io/terraform-infra/index.yaml

### Container builds

All custom container build Dockerfiles are at https://github.com/randomcoww/container-builds

### Build terrafrom wrapper image

```bash
TF_VERSION=1.1.2
SSH_VERSION=0.1.4
SYNCTHING_VERSION=0.1.2
TAG=ghcr.io/randomcoww/tw:latest

buildah build \
  --build-arg TF_VERSION=$TF_VERSION \
  --build-arg SSH_VERSION=$SSH_VERSION \
  --build-arg SYNCTHING_VERSION=$SYNCTHING_VERSION \
  -f Dockerfile \
  -t $TAG && \

buildah push $TAG
```

### Cleanup terraform file formatting

```bash
tw find . -name '*.tf' -exec terraform fmt '{}' \;
```
