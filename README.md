## Provisioning

### Environment

#### Define the `tw` (terraform wrapper) command

```bash
mkdir -p $HOME/.kube $HOME/.aws

tw() {
  set -x
  podman run -it --rm --security-opt label=disable \
    --entrypoint='' \
    -v $(pwd):/tf \
    -v $HOME/.aws:/root/.aws \
    -v $HOME/.kube:/root/.kube \
    -e KUBE_CONFIG_PATH=/root/.kube/config \
    -w /tf \
    --net=host \
    docker.io/hashicorp/terraform:latest "$@"
  rc=$?; set +x; return $rc
}
```

#### Create `ignition_config/secrets.tfvars` file

Generate Linux password hash

```bash
PASSWORD=
LINUX_PASSWORD_HASH=$(echo $PASSWORD | openssl passwd -6 -stdin)
```

```bash
cat > ignition_config/secrets.tfvars <<EOF
users = {
  admin = {}
  client = {
    password_hash = "$LINUX_PASSWORD_HASH"
  }
}
EOF
```

### Create bootable OS images

#### Generate CoreOS ignition for all nodes

```bash
tw terraform -chdir=ignition_config init
tw terraform -chdir=ignition_config apply -var-file=secrets.tfvars
```

#### Generate client credentials

```bash
cat > client/secrets.tfvars <<EOF
ssh_client = {
  key_id                = "$(whoami)"
  public_key            = "ssh_client_public_key=$(cat $HOME/.ssh/id_ecdsa.pub)"
  early_renewal_hours   = 168
  validity_period_hours = 336
}
EOF
```

```bash
tw terraform -chdir=client init
tw terraform -chdir=client apply -auto-approve -var-file=secrets.tfvars
```

```bash
tw terraform -chdir=client output -raw kubeconfig > $HOME/.kube/config
```

```bash
SSH_KEY=$HOME/.ssh/id_ecdsa
tw terraform -chdir=client output -raw ssh_user_cert_authorized_key > $SSH_KEY-cert.pub
```

#### Create custom CoreOS images

See [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom/blob/master/builds/server/README.md)

Embed the ignition files generated above into the image to allow them to boot configured

### Launch temporary local bootstrap service to PXE boot servers

`assets_path` should contains PXE image builds of `fedora-coreos-config-custom`

```bash
export host_ip=$(ip -br addr show lan | awk '{print $3}')
export assets_path=${HOME}/store/boot

echo host_ip=$host_ip
echo assets_path=$assets_path
```

```bash
tw terraform -chdir=bootstrap_server init
tw terraform -chdir=bootstrap_server apply \
  -var host_ip=$host_ip \
  -var assets_path=$assets_path
```

Launch manifest with kubelet

```bash
tw terraform -chdir=bootstrap_server output -raw manifest > bootstrap.yaml
sudo podman play kube bootstrap.yaml
```

Populate bootstrap service with PXE boot configuration

```bash
tw terraform -chdir=bootstrap_client apply -var host_ip=$host_ip
```

Stop service after PXE boot stack is launched on Kubernetes

```bash
sudo podman play kube bootstrap.yaml --down

tw terraform -chdir=bootstrap_server destroy \
  -var host_ip=$host_ip \
  -var assets_path=$assets_path
```

### Deploy services to Kubernetes

#### Check that `kubernetes` service is up

```bash
kubectl get svc
```

#### Create `helm_client/secrets.tfvars` file

Define secrets

[Generate Authelia password hash](https://www.authelia.com/reference/guides/passwords/#user--password-file)

```bash
PASSWORD=
LETSENCRYPT_USER=
GMAIL_USER=
GMAIL_PASSWORD=
CLOUDFLARE_API_TOKEN=
CLOUDFLARE_ACCOUNT_ID=
AP_SSID=
AP_COUNTRY_CODE=
AP_CHANNEL=
TS_AUTH_KEY=
WG_PRIVATE_KEY=
WG_ADDRESS=
WG_PUBLIC_KEY=
WG_ENDPOINT=
PASSWORD_HASH=$(podman run --rm docker.io/authelia/authelia:latest authelia hash-password -- "$PASSWORD" | sed 's:.*\: ::')
```

```bash
cat > helm_client/secrets.tfvars <<EOF
letsencrypt = {
  email = "$LETSENCRYPT_USER"
}

cloudflare = {
  api_token  = "$CLOUDFLARE_API_TOKEN"
  account_id = "$CLOUDFLARE_ACCOUNT_ID"
}

authelia_users = {
  "$GMAIL_USER" = {
    password = "$AUTHELIA_PASSWORD_HASH"
  }
}

hostapd = {
  sae_password = "$PASSWORD"
  ssid         = "$AP_SSID"
  country_code = "$AP_COUNTRY_CODE"
  channel      = $AP_CHANNEL
}

smtp = {
  host     = "smtp.gmail.com"
  port     = 587
  username = "$GMAIL_USER"
  password = "$GMAIL_PASSWORD"
}

tailscale = {
  auth_key = "$TS_AUTH_KEY"
}

wireguard_client = {
  Interface = {
    PrivateKey = "$WG_PRIVATE_KEY"
    Address    = "$WG_ADDRESS"
  }
  Peer = {
    PublicKey  = "$WG_PUBLIC_KEY"
    AllowedIPs = "0.0.0.0/0,::0/0"
    Endpoint   = "$WG_ENDPOINT"
  }
}
EOF
```

```bash
tw terraform -chdir=helm_client init
tw terraform -chdir=helm_client apply -var-file=secrets.tfvars
```

This will provision services used in following steps

### Create PXE boot entry for nodes

#### MinIO access

Write configuration for `mc`

```bash
mkdir -p ~/.mc && \
tw terraform -chdir=helm_client \
  output -json mc_config > ~/.mc/config.json
```

#### Push OS images generated previously into Minio

See [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom/blob/master/builds/server/README.md)

#### Write matchbox PXE boot config

Update image tags [here](https://github.com/randomcoww/homelab/blob/master/config_pxeboot.tf#L2) with those pushed in previous step

Check that matchbox pods are running

```bash
kubectl get po -l app=matchbox
```

Once pods are running write PXE boot configuration for all nodes to matchbox

```bash
tw terraform -chdir=pxeboot_config_client init
tw terraform -chdir=pxeboot_config_client apply
```

Each node may be PXE booted now and boot disks are no longer needed as long as two or more nodes are running

### Cleanup terraform file formatting

```bash
tw find . -name '*.tf' -exec terraform fmt '{}' \;
```

## Personal desktop setup

#### Silverblue desktop

```bash
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak --user -y install --or-update flathub \
  com.brave.Browser \
  com.visualstudio.code \
  org.inkscape.Inkscape \
  org.blender.Blender \
  org.godotengine.Godot \
  com.github.xournalpp.xournalpp \
  org.nomacs.ImageLounge \
  org.kde.okular \
  com.valvesoftware.Steam \
  com.heroicgameslauncher.hgl \
  net.lutris.Lutris \
  net.davidotek.pupgui2
```
Manual settings for now

- Add `--socket=wayland` to godot flatpak arg
- Add `--socket=wayland` to vscode flatpak arg
- Add `--ozone-platform-hint=wayland` to vscode arg
- Add `--ozone-platform-hint=wayland --enable-features=WebRTCPipeWireCapturer` to brave arg

Install Minio client

```bash
mkdir -p $HOME/bin
wget -O $HOME/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x $HOME/bin/mc
```

#### Mac desktop

```bash
brew install \
  helm \
  podman \
  kubernetes-cli \
  minio-mc

brew install --cask \
  blender \
  brave-browser \
  godot \
  huiontablet \
  inkscape \
  moonlight \
  tailscale \
  visual-studio-code
```

#### ChromeOS desktop

Enable developer mode and run as `chronos`

```bash
sudo crossystem dev_boot_usb=1
sudo crossystem dev_boot_altfw=1
```

Install RW_LEGACY firmware from https://mrchromebox.tech/#fwscript

Boot to Linux and create a home directory

```bash
sudo lvcreate -V 100G -T $VG_NAME/thinpool -n linux-home
sudo mkfs.xfs -s size=4096 -L pv /dev/$VG_NAME/linux-home

sudo mount /dev/disk/by-label/pv /mnt
sudo mkdir -p /mnt/$(whoami)
sudo chown $(id -u):$(id -g) /mnt/$(whoami)
cp -r /etc/skel/. /mnt/$(whoami)
sudo umount /mnt
```

## :construction: Desktop VM with GPU passthrough :construction:

> This is currently just a POC and serves nothing

Enable a combination of the following `vfio-pci.ids` kargs in [PXE boot params](config_pxeboot.tf)

Stub all Nvidia GPUs

```
10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff
```

Stub all AMD GPUs

```
1002:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,1002:ffffffff:ffffffff:ffffffff:00040300:ffffffff
```

Update the following evdev input devices in the [libvirt config](libvirt/de-1-pt.xml) to match current hardware

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

Create persistent disk for home

```bash
dd if=/dev/zero of=/var/home/qemu/de-1-pt.img bs=1G count=0 seek=100
```

Define and launch guest

```bash
virsh define libvirt/de-1-pt.xml
virsh start de-1-pt
```

No video output is available unless a display is attached to the GPU being passed through
