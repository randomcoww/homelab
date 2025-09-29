## Terraform provisioner for Kubernetes homelab

### Define secrets

Cloudflare API token permissions

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

GitHub PAT permissions

* repo
* workflow

Tailscale auth scopes

* auth_keys
* devices:core:read
* devices:posture_attributes
* dns
* policy_file

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
    docker.io/hashicorp/terraform:latest "$@"
  rc=$?; set +x; return $rc
}
```

---

### Generate credentials

Generate external and cluster wide resources

```bash
terraform -chdir=cluster_resources init -upgrade && \
terraform -chdir=cluster_resources apply -var-file=../secrets.tfvars
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

Generate or update host network boot configuration

```bash
terraform -chdir=ignition init -upgrade && \
terraform -chdir=ignition apply -auto-approve && \
terraform -chdir=matchbox_client init -upgrade && \
terraform -chdir=matchbox_client apply
```

---

### Trigger rolling reboot

Trigger rolling reboot of modified Kubernetes workers coordinated by `kured`.

```bash
terraform -chdir=rolling_reboot init -upgrade && \
terraform -chdir=rolling_reboot apply
```

---

### Deploy services to Kubernetes

Deploy Kubernetes services

```bash
terraform -chdir=kubernetes_service init -upgrade && \
terraform -chdir=kubernetes_service apply -var-file=../secrets.tfvars
```

Create MinIO resources

```bash
terraform -chdir=minio_resources init -upgrade && \
terraform -chdir=minio_resources apply
```