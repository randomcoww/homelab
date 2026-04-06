# Cloudflare

output "cloudflare_dns_api_token" {
  value     = cloudflare_api_token.dns.value
  sensitive = true
}

output "r2_bucket" {
  value = {
    for _, name in concat(local.r2_buckets, [
      data.terraform_remote_state.sr.config.bucket,
    ]) :

    name => {
      url               = "${local.cloudflare_account_id}.r2.cloudflarestorage.com"
      bucket            = name
      access_key_id     = cloudflare_api_token.r2_bucket[name].id
      secret_access_key = sha256(cloudflare_api_token.r2_bucket[name].value)
    }
  }
  sensitive = true
}

output "cloudflare_tunnel" {
  value = merge({
    for _, k in [
      "account_id",
      "name",
      "id",
      "tunnel_secret",
    ] :
    k => cloudflare_zero_trust_tunnel_cloudflared.tunnel[k]
  })
  sensitive = true
}

# Tailscale

output "tailscale_auth_key" {
  value     = tailscale_tailnet_key.auth.key
  sensitive = true
}

output "letsencrypt" {
  value = {
    private_key_pem = tls_private_key.letsencrypt-prod.private_key_pem
    username        = var.letsencrypt_username
  }
  sensitive = true
}

# storage access from rclone

output "rclone_config" {
  value     = <<EOF
%{~for _, name in concat(local.r2_buckets, [data.terraform_remote_state.sr.config.bucket])~}
[cf-${name}]
type = s3
provider = Cloudflare
access_key_id = ${cloudflare_api_token.r2_bucket[name].id}
secret_access_key = ${sha256(cloudflare_api_token.r2_bucket[name].value)}
region = auto
endpoint = https://${local.cloudflare_account_id}.r2.cloudflarestorage.com
%{endfor~}
EOF
  sensitive = true
}