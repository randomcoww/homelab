
### Define external secrets

Create service keys.

Cloudflare API token permissions:

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

GitHub PAT permissions:

* repo
* workflow

Tailscale auth scopes:

* auth_keys
* devices:core:read
* devices:posture_attributes
* dns
* policy_file

Cloudflare permissions reference:

```bash
curl https://api.cloudflare.com/client/v4/user/tokens/permission_groups --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq
```

Add keys to `secrets.tfvars`.

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

---

Set up access for Terraform backend on Cloudflare.

```bash
cat > credentials.env <<EOF
AWS_ENDPOINT_URL_S3=https://$(curl https://api.cloudflare.com/client/v4/accounts --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result.[0].id').r2.cloudflarestorage.com
AWS_ACCESS_KEY_ID=$(curl https://api.cloudflare.com/client/v4/user/tokens/verify --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result.id')
AWS_SECRET_ACCESS_KEY=$(echo -n $CLOUDFLARE_API_TOKEN | sha256sum --quiet)
EOF
```

---

### Generate cluster resources

Generate external and other cluster wide resources like CAs.

```bash
terraform -chdir=cluster_resources init -upgrade && \
terraform -chdir=cluster_resources apply -var-file=../secrets.tfvars
```

---

### Bootstrap hosts over the network

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
terraform -chdir=bootstrap_server init -upgrade && \
terraform -chdir=bootstrap_server apply \
  -var host_ip=$host_ip \
  -var assets_path=$assets_path
```

Launch bootstrap service with Podman.

```bash
terraform -chdir=bootstrap_server output -raw pod_manifest > bootstrap.yaml
sudo podman play kube bootstrap.yaml
```

Push PXE boot and ignition configuration to bootstrap service.

```bash
terraform -chdir=ignition init -upgrade && \
terraform -chdir=ignition apply -auto-approve && \
terraform -chdir=bootstrap_client init -upgrade && \
terraform -chdir=bootstrap_client apply
```

Start all servers and allow them to PXE boot.

Bootstrap service can be stopped once servers are up.

```bash
sudo podman play kube bootstrap.yaml --down

terraform -chdir=bootstrap_server destroy \
  -var host_ip=$host_ip \
  -var assets_path=$assets_path
```