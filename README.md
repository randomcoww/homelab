# Terraform (OpenTofu) provisioner for Kubernetes homelab

Run Terraform in container (optional):

```bash
tofu() {
  set -x
  podman run -it --rm --security-opt label=disable \
    -v $(pwd):$(pwd) \
    -w $(pwd) \
    --env-file=credentials.env \
    --net=host \
    ghcr.io/opentofu/opentofu:latest "$@"
  rc=$?; set +x; return $rc
}
```

## External dependencies

### Create service tokens

Cloudflare API token permissions:

```bash
curl https://api.cloudflare.com/client/v4/user/tokens/permission_groups --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq
```

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

### Generate secrets files

Add keys to `secrets.tfvars`:

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

github = {
  username = "randomcoww"
  token    = "$GITHUB_TOKEN"
}

smtp = {
  host     = "smtp.gmail.com"
  port     = 587
  username = "$GMAIL_USER"
  password = "$GMAIL_PASSWORD"
}
EOF
```

Set `credentials.env` to use Cloudflare R2 for Terraform backend:

```bash
cat > credentials.env <<EOF
AWS_ENDPOINT_URL_S3=https://$(curl https://api.cloudflare.com/client/v4/accounts --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result.[0].id').r2.cloudflarestorage.com
AWS_ACCESS_KEY_ID=$(curl https://api.cloudflare.com/client/v4/user/tokens/verify --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result.id')
AWS_SECRET_ACCESS_KEY=$(echo -n $CLOUDFLARE_API_TOKEN | sha256sum --quiet)
EOF
```

### Run external configuration

Generate external and other cluster wide resources like CAs:

```bash
tofu -chdir=cloud_resources init -upgrade && \
tofu -chdir=cloud_resources apply -var-file=../secrets.tfvars
```

## Internal resources

### Build OS images

See [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom)

If the internal cluster is up, call `image-build` workflow in the repo above to generate a new image. Run `renovate` workflow in this repo to update to using the new image.

### Create host configuration and secrets

Create host ignition and secrets:

```bash
tofu -chdir=host_provisioning init -upgrade && \
tofu -chdir=host_provisioning apply
```

### Deploy services to Kubernetes

Deploy Kubernetes services. Some services rely on MinIO and will crash loop until MinIO resources are created (below).

```bash
tofu -chdir=helm_release init -upgrade && \
tofu -chdir=helm_release apply -var-file=../secrets.tfvars
```

Create MinIO resources and secrets containing access credentials in Kubernetes. MinIO must be running in Kubernetes for this to work.

```bash
tofu -chdir=minio_resources init -upgrade && \
tofu -chdir=minio_resources apply
```

### Roll out host updates

Trigger rolling reboot of hosts coordinated by `kured`. Nodes occasionally fail to network boot falling back to booting from backup USB disk. `kured` will also attempt to restart nodes in this state.

```bash
tofu -chdir=rolling_reboot init -upgrade && \
tofu -chdir=rolling_reboot apply
```

## Service management

Generate local credentials to local state:

```bash
tofu -chdir=local_credentials init -upgrade && \
tofu -chdir=local_credentials apply -auto-approve -var "ssh_client={key_id=\"$(whoami)\",public_key_openssh=\"ssh_client_public_key=$(cat $HOME/.ssh/id_ecdsa.pub)\"}"
```

Internal CA:

```bash
tofu -chdir=host_provisioning output -json internal_ca | jq -r '.cert_pem' > $HOME/ca.crt
```

SSH CA client:

```bash
SSH_KEY=$HOME/.ssh/id_ecdsa
tofu -chdir=local_credentials output -raw ssh_user_cert_authorized_key > $SSH_KEY-cert.pub
```

Admin kubeconfig:

```bash
tofu -chdir=local_credentials output -raw kubeconfig > $HOME/.kube/config
```

Internal S3:

```bash
mkdir -p $HOME/.mc/certs/CAs
tofu -chdir=host_provisioning output -json internal_ca | jq -r '.cert_pem' > $HOME/.mc/certs/CAs/ca.crt
tofu -chdir=helm_release output -raw mc_config > $HOME/.mc/config.json

mkdir -p $HOME/.config/rclone
cat > $HOME/.config/rclone/rclone.conf <<EOF
[m]
type = s3
provider = Minio
access_key_id = $(tofu -chdir=helm_release output -json minio | jq -r '.access_key_id')
secret_access_key = $(tofu -chdir=helm_release output -json minio | jq -r '.secret_access_key')
region = auto
endpoint = https://$(tofu -chdir=helm_release output -json minio | jq -r '.endpoint')
override.ca_cert = $HOME/.mc/certs/CAs/ca.crt

$(tofu -chdir=cloud_resources output -raw rclone_config)
EOF
```

LDAP admin:

```bash
tofu -chdir=helm_release output -json lldap | jq
```

llama.cpp API key:

```bash
tofu -chdir=helm_release output -json llama-cpp | jq
```

Internal registry:

```bash
regctl registry set reg.cluster.internal \
  --tls enabled \
  --cacert "$(tofu -chdir=host_provisioning output -json internal_ca | jq -r '.cert_pem')" \
  --client-cert "$(tofu -chdir=local_credentials output -json registry_client | jq -r '.cert_pem')" \
  --client-key "$(tofu -chdir=local_credentials output -json registry_client | jq -r '.private_key_pem')"

regctl repo ls reg.cluster.internal
regctl tag ls reg.cluster.internal/${REPO}
regctl tag delete reg.cluster.internal/${REPO}:${TAG}
```

## Repo notes

### Update helm chart

```bash
helm package helm-wrapper/ -d docs/
helm repo index docs/ --url https://randomcoww.github.io/homelab/
```

### Renovate local test

```bash
GITHUB_TOKEN=<token>

podman run -it --rm \
  -v $(pwd):$(pwd) \
  -w $(pwd) \
  -e RENOVATE_TOKEN=$GITHUB_TOKEN \
  -e GITHUB_COM_TOKEN=$GITHUB_TOKEN \
  -e LOG_LEVEL=debug \
  ghcr.io/renovatebot/renovate \
  bash
```

```bash
renovate --platform=local --dry-run
```
