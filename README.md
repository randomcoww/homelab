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
    docker.io/hashicorp/terraform:1.10.5 "$@"
  rc=$?; set +x; return $rc
}
```

Define secrets

```bash
LETSENCRYPT_USER=
CLOUDFLARE_API_TOKEN=
CLOUDFLARE_ACCOUNT_ID=
TS_OAUTH_CLIENT_ID=
TS_OAUTH_CLIENT_SECRET=
GMAIL_USER=
GMAIL_PASSWORD=
GITHUB_ARC_TOKEN=
```

Create `cluster_resources/secrets.tfvars` file

```bash
cat > cluster_resources/secrets.tfvars <<EOF
letsencrypt_username  = "$LETSENCRYPT_USER"

cloudflare = {
  api_token  = "$CLOUDFLARE_API_TOKEN"
  account_id = "$CLOUDFLARE_ACCOUNT_ID"
}

tailscale = {
  oauth_client_id     = "$TS_OAUTH_CLIENT_ID"
  oauth_client_secret = "$TS_OAUTH_CLIENT_SECRET"
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

Create `kubernetes_service/secrets.tfvars` file

```bash
cat > kubernetes_service/secrets.tfvars <<EOF
smtp = {
  host     = "smtp.gmail.com"
  port     = 587
  username = "$GMAIL_USER"
  password = "$GMAIL_PASSWORD"
}

github = {
  arc_token = "$GITHUB_ARC_TOKEN"
}
EOF
```

---

### Generate credentials

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

In cluster kubeconfig

```bash
tw terraform -chdir=client_credentials output -raw kubeconfig_cluster > $HOME/.kube/config
```

---

### Build OS images

See [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom)

Image build can be triggered from Github actions if ARC runners and MinIO are up. A pull request should get created to update the boot image tag. Update check may be forced by running the renovate Github workflow under this repo.

Generate host ignition

```bash
tw terraform -chdir=ignition init
tw terraform -chdir=ignition apply
```

Push image tag and ignition to matchbox for iPXE boot

```bash
tw terraform -chdir=matchbox_client init
tw terraform -chdir=matchbox_client apply
```

---

### Deploy services to Kubernetes

Deploy critical bootstrap and services

```bash
tw terraform -chdir=kubernetes_bootstrap init
tw terraform -chdir=kubernetes_bootstrap apply
```

Deploy higher level services

```bash
tw terraform -chdir=kubernetes_service init
tw terraform -chdir=kubernetes_service apply -var-file=secrets.tfvars
```

---

### Create user

Go to `https://ldap.fuzzybunny.win`

Get admin password by running

```bash
tw terraform -chdir=cluster_resources output -json lldap
```

Set up 2FA at `https://auth.fuzzybunny.win`

---

### Write current PXE boot image to local disk

If network boot is not working, hosts may fallback to booting from (USB) disk.

```bash
export IMAGE_URL=$(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url= | sed -r 's/coreos.live.rootfs_url=(.*)-rootfs(.*)\.img$/\1\2.iso/')
export IGNITION_URL=$(xargs -n1 -a /proc/cmdline | grep ^ignition.config.url= | sed 's/ignition.config.url=//')
export DISK=/dev/$(lsblk -ndo pkname /dev/disk/by-label/fedora-*)

echo image-url=$IMAGE_URL
echo ignition-url=$IGNITION_URL
echo disk=$DISK
sudo lsof $DISK
```

```bash
curl $IMAGE_URL --output coreos.iso
curl $IGNITION_URL | coreos-installer iso ignition embed coreos.iso

sudo dd if=coreos.iso of=$DISK bs=4M
sync
rm coreos.iso
```

---

### Committing

Formatting for terraform files

```bash
tw find . -name '*.tf' -exec terraform fmt '{}' \;
```

---

### Full cluster restart over the network

Launch bootstrap DHCP service on a workstation on the same network as the server. Path `assets_path` should contains PXE image builds from [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom).

Update image tags under `pxeboot_images` in [environment config](https://github.com/randomcoww/homelab/blob/master/config_env.tf) to match image file names.


```bash
export interface=br-lan
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
tw terraform -chdir=bootstrap_server output -raw pod_manifest > bootstrap.yaml
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