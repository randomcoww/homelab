# Terraform (OpenTofu) provisioner for Kubernetes homelab

## External dependencies

### Create service tokens

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

```bash
curl https://api.cloudflare.com/client/v4/user/tokens/permission_groups --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq
```

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

```bash
[ -f $HOME/.ssh/id_ecdsa ] || ssh-keygen -t ecdsa -f $HOME/.ssh/id_ecdsa -N ""

cat > credentials.env <<EOF
TF_VAR_cloudflare_api_token=$CLOUDFLARE_API_TOKEN
TF_VAR_letsencrypt_username=$LETSENCRYPT_USER
TF_VAR_tailscale_oauth_client_id=$TS_OAUTH_CLIENT_ID
TF_VAR_tailscale_oauth_client_secret=$TS_OAUTH_CLIENT_SECRET
TF_VAR_github_username=$(whoami)
TF_VAR_github_token=$GITHUB_TOKEN
TF_VAR_smtp_host=smtp.gmail.com
TF_VAR_smtp_username=$GMAIL_USER
TF_VAR_smtp_password=$GMAIL_PASSWORD
TF_VAR_scrape_proxy_server=$THORDATA_SERVER
TF_VAR_scrape_proxy_username=$THORDATA_USERNAME
TF_VAR_scrape_proxy_password=$THORDATA_PASSWORD
TF_VAR_ssh_client_key_id=$(whoami)
TF_VAR_ssh_client_public_key_openssh=$(cat $HOME/.ssh/id_ecdsa.pub)
TF_VAR_slack_bot_token=$SLACK_BOT_TOKEN
TF_VAR_slack_app_token=$SLACK_APP_TOKEN
TF_VAR_slack_allowed_users=$SLACK_ALLOWED_USERS
TF_VAR_slack_home_channel=$SLACK_HOME_CHANNEL
AWS_ENDPOINT_URL_S3=https://$(curl https://api.cloudflare.com/client/v4/accounts --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result.[0].id').r2.cloudflarestorage.com
AWS_ACCESS_KEY_ID=$(curl https://api.cloudflare.com/client/v4/user/tokens/verify --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result.id')
AWS_SECRET_ACCESS_KEY=$(echo -n $CLOUDFLARE_API_TOKEN | sha256sum --quiet)
EOF
```

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

### Run external configuration

Generate external and other cluster wide resources like CAs:

```bash
tofu -chdir=cloud_resources init -upgrade && \
tofu -chdir=cloud_resources apply
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

Bootstrap low level Kubernetes services needed for FluxCD including MinIO.

```bash
tofu -chdir=cluster_bootstrap init -upgrade && \
tofu -chdir=cluster_bootstrap apply
```

Create resources on MinIO needed for host provisioning and FluxCD Kustomizations. This may also trigger a rolling reboot of hosts managed by Kured.

```bash
tofu -chdir=s3_resources init -upgrade && \
tofu -chdir=s3_resources apply
```

## Service management

Generate local credentials to local state:

```bash
tofu -chdir=local_credentials init -upgrade && \
tofu -chdir=local_credentials apply
```

SSH CA client:

```bash
SSH_KEY=$HOME/.ssh/id_ecdsa
tofu -chdir=local_credentials output -raw ssh_user_cert_authorized_key > $SSH_KEY-cert.pub
```

Admin kubeconfig:

```bash
mkdir -p $HOME/.kube
tofu -chdir=local_credentials output -raw kubeconfig > $HOME/.kube/config
```

Internal S3:

```bash
mkdir -p $HOME/.mc/certs/CAs
tofu -chdir=host_provisioning output -json internal_ca | jq -r '.cert_pem' > $HOME/.mc/certs/CAs/ca.crt
cat > $HOME/.mc/config.json <<EOF
$(tofu -chdir=cluster_bootstrap output -json minio | jq -r '
  {
    aliases: {
      m: {
        accessKey: .access_key_id,
        api: "S3v4",
        path: "auto",
        secretKey: .secret_access_key,
        url: "https://\(.endpoint)"
      }
    },
    version: "10"
  }
')
EOF

mkdir -p $HOME/.config/rclone
cat > $HOME/.config/rclone/rclone.conf <<EOF
$(tofu -chdir=cluster_bootstrap output -json minio | jq -r '
  "[m]",
  "type = s3",
  "provider = Minio",
  "access_key_id = \(.access_key_id)",
  "secret_access_key = \(.secret_access_key)",
  "region = auto",
  "endpoint = https://\(.endpoint)"
')
override.ca_cert = $HOME/.mc/certs/CAs/ca.crt

$(tofu -chdir=cloud_resources output -json r2_bucket | jq -r '
  to_entries |
  map(
    [
      "[cf-\(.value.bucket)]",
      "type = s3",
      "provider = Cloudflare",
      "access_key_id = \(.value.access_key_id)",
      "secret_access_key = \(.value.secret_access_key)",
      "region = auto",
      "endpoint = https://\(.value.url)"
    ] | join("\n")
  ) |
  join("\n\n")
')
EOF
```

LDAP admin:

```bash
tofu -chdir=s3_resources output lldap
```

llama.cpp OpenAI compatible endpoint:

```bash
tofu -chdir=s3_resources output llama-cpp
```

Hermes Agent OpenAI compatible endpoint:

```bash
tofu -chdir=s3_resources output hermes-agent
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

Force a rolling reboot of hosts:

```bash
tofu -chdir=rolling_reboot init -upgrade && \
tofu -chdir=rolling_reboot apply
```

## Notes

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
