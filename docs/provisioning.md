
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

---

### Generate secrets files

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

Set `credentials.env` to use Cloudflare R2 for Terraform backend.

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

TODO: Update bootstrap process