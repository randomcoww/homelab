### Configure environment

Define the `tw` (terraform wrapper) command

```bash
mkdir -p $HOME/.kube $HOME/.aws

tw() {
  set -x
  podman run -it --rm --security-opt label=disable \
    --entrypoint='' \
    -v $(pwd):$(pwd) \
    -v $HOME/.aws:/root/.aws \
    -v $HOME/.kube:/root/.kube \
    -e KUBE_CONFIG_PATH=/root/.kube/config \
    -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    -w $(pwd) \
    --net=host \
    docker.io/hashicorp/terraform:1.4.7 "$@"
  rc=$?; set +x; return $rc
}
```

Create `cluster_resources/secrets.tfvars` file

```bash
CLOUDFLARE_API_TOKEN=
CLOUDFLARE_ACCOUNT_ID=
LETSENCRYPT_USER=
```

```bash
cat > cluster_resources/secrets.tfvars <<EOF
cloudflare_api_token  = "$CLOUDFLARE_API_TOKEN"
cloudflare_account_id = "$CLOUDFLARE_ACCOUNT_ID"
letsencrypt_username  = "$LETSENCRYPT_USER"
EOF
```

Create `ignition/secrets.tfvars` file

```bash
LINUX_PASSWORD_HASH=$(echo $PASSWORD | openssl passwd -6 -stdin)
```

```bash
cat > ignition/secrets.tfvars <<EOF
users = {
  admin = {}
  client = {
    password_hash = "$LINUX_PASSWORD_HASH"
  }
}
EOF
```

Create `client_credentials/secrets.tfvars` file

```bash
cat > client_credentials/secrets.tfvars <<EOF
ssh_client = {
  key_id                = "$(whoami)"
  public_key_openssh    = "ssh_client_public_key=$(cat $HOME/.ssh/id_ecdsa.pub)"
  early_renewal_hours   = 168
  validity_period_hours = 336
}
EOF
```

Create `kubernetes_client/secrets.tfvars` file

Reference: [Generate Authelia password hash](https://www.authelia.com/reference/guides/passwords/#user--password-file)

```bash
GMAIL_USER=
GMAIL_PASSWORD=
AP_PASSWORD=
AP_SSID=
AP_COUNTRY_CODE=
AP_CHANNEL=
TS_AUTH_KEY=
WG_PRIVATE_KEY=
WG_ADDRESS=
WG_PUBLIC_KEY=
WG_ENDPOINT=
APCA_API_KEY_ID=
APCA_API_SECRET_KEY=
APCA_API_BASE_URL=
```

```bash
cat > kubernetes_client/secrets.tfvars <<EOF
hostapd = {
  sae_password = "$AP_PASSWORD"
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

wireguard_client = {
  private_key = "$WG_PRIVATE_KEY"
  public_key  = "$WG_PUBLIC_KEY"
  address     = "$WG_ADDRESS"
  endpoint    = "$WG_ENDPOINT"
}

tailscale = {
  auth_key = "$TS_AUTH_KEY"
}

alpaca = {
  api_key_id     = "$APCA_API_KEY_ID"
  api_secret_key = "$APCA_API_SECRET_KEY"
  api_base_url   = "$APCA_API_BASE_URL"
}
EOF
```

---

### Generate server ignition configuration

Generate cluster resources

```bash
tw terraform -chdir=cluster_resources init
tw terraform -chdir=cluster_resources apply -var-file=secrets.tfvars
```

Write client credentials

```bash
tw terraform -chdir=client_credentials init
tw terraform -chdir=client_credentials apply -auto-approve -var-file=secrets.tfvars

tw terraform -chdir=client_credentials output -raw kubeconfig > $HOME/.kube/config

SSH_KEY=$HOME/.ssh/id_ecdsa
tw terraform -chdir=client_credentials output -raw ssh_user_cert_authorized_key > $SSH_KEY-cert.pub

mkdir -p $HOME/.mc
tw terraform -chdir=client_credentials output -json mc_config > $HOME/.mc/config.json
```

Generate ignition config for servers

```bash
tw terraform -chdir=ignition init
tw terraform -chdir=ignition apply -var-file=secrets.tfvars
```

Build OS images (see [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom))

---

### Bootstrap servers

Launch bootstrap DHCP service on a workstation on the same network as the server

Path `assets_path` should contains PXE image builds from [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom)

Update image tags under `pxeboot_images` in [environment config](https://github.com/randomcoww/homelab/blob/master/config_env.tf) to match image file names


```bash
export interface=lan
export host_ip=$(ip -br addr show $interface | awk '{print $3}')
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

Launch bootstrap service with Podman

```bash
tw terraform -chdir=bootstrap_server output -raw manifest > bootstrap.yaml
sudo podman play kube bootstrap.yaml
```

Push PXE boot and ignition configuration to bootstrap service

```bash
tw terraform -chdir=bootstrap_client init
tw terraform -chdir=bootstrap_client apply
```

Start all servers and allow them to PXE boot

Bootstrap service can be stopped once servers are up

```bash
sudo podman play kube bootstrap.yaml --down

tw terraform -chdir=bootstrap_server destroy \
  -var host_ip=$host_ip \
  -var assets_path=$assets_path
```

---

### Deploy services to Kubernetes

Check that `kubernetes` service is up

```bash
kubectl get svc
```

Deploy helm charts to Kubernetes

```bash
tw terraform -chdir=kubernetes_client init
tw terraform -chdir=kubernetes_client apply -var-file=secrets.tfvars
```

---

### Conifgure PXE boot from cluster

Push images generated previously into Minio (see [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom))

Update image tags under `pxeboot_images` in [environment config](https://github.com/randomcoww/homelab/blob/master/config_env.tf) to match image file names

Check that matchbox pods are running

```bash
kubectl get po -l app=matchbox
```

Push PXE boot and ignition configuration to cluster bootstrap service

```bash
tw terraform -chdir=matchbox_client init
tw terraform -chdir=matchbox_client apply
```

Each node will now be able to PXE boot from the cluster as long as only one node is taken down at a time

---

### Committing

Formatting for terraform files

```bash
tw find . -name '*.tf' -exec terraform fmt '{}' \;
```

---

### Desktop setup

#### Fedora Silverblue

```bash
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak --user -y install --or-update flathub \
  com.brave.Browser \
  com.visualstudio.code \
  org.inkscape.Inkscape \
  org.kde.krita \
  org.blender.Blender \
  com.github.xournalpp.xournalpp \
  com.valvesoftware.Steam \
  com.heroicgameslauncher.hgl \
  net.lutris.Lutris \
  net.davidotek.pupgui2
```

Install Minio client

```bash
mkdir -p $HOME/bin
wget -O $HOME/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x $HOME/bin/mc
```

#### Mac

```bash
brew install \
  helm \
  podman \
  kubernetes-cli \
  minio-mc

brew install --cask \
  blender \
  brave-browser \
  huiontablet \
  inkscape \
  krita \
  moonlight \
  tailscale \
  visual-studio-code
```

#### ChromeOS Crostini

```bash
vsh termina
lxc config set penguin security.nesting true
lxc restart penguin
```

```bash
sudo apt install -y \
  kubernetes-client \
  podman \
  flatpak

echo $(whoami):100000:65536 | sudo tee -a /etc/subuid /etc/subgid

sudo tee /etc/containers/containers.conf > /dev/null <<EOF
[containers]
keyring = false
EOF
```

```bash
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak --user -y install flathub \
  com.visualstudio.code
```

Install helm https://helm.sh/docs/intro/install/

#### ChromeOS Linux dual-boot

Enable developer mode and run as `chronos`

```bash
sudo crossystem dev_boot_usb=1
sudo crossystem dev_boot_altfw=1
```

Install RW_LEGACY firmware from https://mrchromebox.tech/#fwscript

Boot Linux from USB and create a home directory

```bash
sudo lvcreate -V 100G -T $VG_NAME/thinpool -n home
sudo mkfs.xfs -s size=4096 -L home /dev/$VG_NAME/home

sudo mount /dev/disk/by-label/home /mnt
sudo mkdir -p /mnt/$(whoami)
sudo chown $(id -u):$(id -g) /mnt/$(whoami)
cp -r /etc/skel/. /mnt/$(whoami)
sudo umount /mnt
```