## Terraform provisioner for Kubernetes homelab

### Configure environment

Define Terraform secrets

```bash
CLOUDFLARE_API_TOKEN=
LETSENCRYPT_USER=
TS_OAUTH_CLIENT_ID=
TS_OAUTH_CLIENT_SECRET=
GMAIL_USER=
GMAIL_PASSWORD=
GITHUB_ARC_TOKEN=
```

Cloudflare API token needs the following permissions

| | | |
--- | --- | ---
Account | Workers R2 Storage | Edit
Account | Account Rulesets | Edit
Account | Cloudflare Tunnel | Edit
Account | Zero Trust | Edit
User | API Tokens | Edit
Zone | Config Rules | Edit
Zone | Zone Settings | Edit
Zone | SSL and Certificates | Edit
Zone | DNS | Edit

Look up Cloudflare permissions

```bash
curl https://api.cloudflare.com/client/v4/user/tokens/permission_groups --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq
```

Set env to use Terraform S3 backend on Cloudflare R2

```bash
cat > credentials.env <<EOF
AWS_ENDPOINT_URL_S3=https://$(curl https://api.cloudflare.com/client/v4/accounts --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result.[0].id').r2.cloudflarestorage.com
AWS_ACCESS_KEY_ID=$(curl https://api.cloudflare.com/client/v4/user/tokens/verify --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result.id')
AWS_SECRET_ACCESS_KEY=$(echo -n $CLOUDFLARE_API_TOKEN | sha256sum --quiet)
EOF
```

Create `secrets.tfvars` file

```bash
cat > secrets.tfvars <<EOF
cloudflare = {
  api_token = "$CLOUDFLARE_API_TOKEN"
}

letsencrypt_username  = "$LETSENCRYPT_USER"

tailscale = {
  oauth_client_id     = "$TS_OAUTH_CLIENT_ID"
  oauth_client_secret = "$TS_OAUTH_CLIENT_SECRET"
}

smtp = {
  host     = "smtp.gmail.com"
  port     = 587
  username = "$GMAIL_USER"
  password = "$GMAIL_PASSWORD"
}

github = {
  user  = "randomcoww"
  token = "$GITHUB_TOKEN"
}
EOF
```

Run Terraform in container (optional)

```bash
terraform() {
  set -x
  podman run -it --rm --security-opt label=disable \
    -v $(pwd):$(pwd) \
    -w $(pwd) \
    --env-file=credentials.env \
    --net=host \
    docker.io/hashicorp/terraform:1.13.2 "$@"
  rc=$?; set +x; return $rc
}
```

---

### Generate credentials

Generate external and cluster wide resources

```bash
terraform -chdir=cluster_resources init -upgrade && \
terraform -chdir=cluster_resources apply -var-file=secrets.tfvars
```

Write local client credentials

```bash
terraform -chdir=client_credentials init -upgrade && \
terraform -chdir=client_credentials apply -auto-approve -var "ssh_client={key_id=\"$(whoami)\",public_key_openssh=\"ssh_client_public_key=$(cat $HOME/.ssh/id_ecdsa.pub)\"}"

SSH_KEY=$HOME/.ssh/id_ecdsa
terraform -chdir=client_credentials output -raw ssh_user_cert_authorized_key > $SSH_KEY-cert.pub

terraform -chdir=client_credentials output -raw kubeconfig > $HOME/.kube/config

mkdir -p $HOME/.mc/certs/CAs
terraform -chdir=client_credentials output -json mc_config > $HOME/.mc/config.json
terraform -chdir=client_credentials output -json minio_client | jq -r '.ca_cert_pem' > $HOME/.mc/certs/CAs/ca.crt
```

---

### Build OS images

See [fedora-coreos-config](https://github.com/randomcoww/fedora-coreos-config)

Image build can be triggered from Github actions if ARC runners and MinIO are up. A pull request should get created to update the boot image tag. Update check may be forced by running the renovate Github workflow under this repo.

Generate host ignition

```bash
terraform -chdir=ignition init -upgrade && \
terraform -chdir=ignition apply
```

Push image tag and ignition to matchbox for iPXE boot

```bash
terraform -chdir=matchbox_client init -upgrade && \
terraform -chdir=matchbox_client apply
```

---

### Deploy services to Kubernetes

Deploy bootstrap and lower level services

```bash
terraform -chdir=kubernetes_bootstrap init -upgrade && \
terraform -chdir=kubernetes_bootstrap apply
```

Deploy higher level services

```bash
terraform -chdir=kubernetes_service init -upgrade && \
terraform -chdir=kubernetes_service apply -var-file=secrets.tfvars
```

---

### Trigger rolling reboot

Trigger rolling reboot of modified Kubernetes workers coordinated by `kured`.

```bash
terraform -chdir=rolling_reboot init -upgrade && \
terraform -chdir=rolling_reboot apply
```

Occasionally nodes will fail to boot from network and fallback to backup disk even when the network boot environment is working. `kured` will monitor and reboot these nodes as well.

---

### Full cluster restart over the network

Launch bootstrap DHCP service on a workstation on the same network as the server. Path `assets_path` should contains PXE image builds from [fedora-coreos-config](https://github.com/randomcoww/fedora-coreos-config).

Update image tags under `pxeboot_images` in [environment config](https://github.com/randomcoww/homelab/blob/master/config_env.tf) to match image file names.

```bash
export interface=br-lan
export host_ip=$(ip -br addr show $interface | awk '{print $3}')
export assets_path=${HOME}/store/boot

echo host_ip=$host_ip
echo assets_path=$assets_path
```

```bash
terraform -chdir=bootstrap_server init && \
terraform -chdir=bootstrap_server apply \
  -var host_ip=$host_ip \
  -var assets_path=$assets_path
```

Launch bootstrap service with Podman

```bash
terraform -chdir=bootstrap_server output -raw pod_manifest > bootstrap.yaml
sudo podman play kube bootstrap.yaml
```

Push PXE boot and ignition configuration to bootstrap service

```bash
terraform -chdir=bootstrap_client init && \
terraform -chdir=bootstrap_client apply
```

Start all servers and allow them to PXE boot

Bootstrap service can be stopped once servers are up

```bash
sudo podman play kube bootstrap.yaml --down

terraform -chdir=bootstrap_server destroy \
  -var host_ip=$host_ip \
  -var assets_path=$assets_path
```
