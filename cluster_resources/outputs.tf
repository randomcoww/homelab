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

output "cloudflare_tunnels" {
  value = {
    for tunnel in cloudflare_zero_trust_tunnel_cloudflared.tunnel :
    tunnel.name => merge(tunnel, {
      account_id = local.cloudflare_account_id
    })
  }
  sensitive = true
}

# Tailscale

output "tailscale_auth_key" {
  value     = tailscale_tailnet_key.auth.key
  sensitive = true
}

# Etcd

output "etcd" {
  value = {
    ca = {
      algorithm       = tls_private_key.etcd-ca.algorithm
      private_key_pem = tls_private_key.etcd-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.etcd-ca.cert_pem
    }
    peer_ca = {
      algorithm       = tls_private_key.etcd-peer-ca.algorithm
      private_key_pem = tls_private_key.etcd-peer-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.etcd-peer-ca.cert_pem
    }
  }
  sensitive = true
}

# Kubernetes

output "kubernetes" {
  value = {
    ca = {
      algorithm       = tls_private_key.kubernetes-ca.algorithm
      private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem
    }
    front_proxy_ca = {
      algorithm       = tls_private_key.kubernetes-front-proxy-ca.algorithm
      private_key_pem = tls_private_key.kubernetes-front-proxy-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.kubernetes-front-proxy-ca.cert_pem
    }
    service_account = {
      algorithm       = tls_private_key.service-account.algorithm
      public_key_pem  = tls_private_key.service-account.public_key_pem
      private_key_pem = tls_private_key.service-account.private_key_pem
    }
  }
  sensitive = true
}

##

output "ssh" {
  value = {
    ca = {
      algorithm          = tls_private_key.ssh-ca.algorithm
      private_key_pem    = tls_private_key.ssh-ca.private_key_pem
      public_key_openssh = tls_private_key.ssh-ca.public_key_openssh
    }
  }
  sensitive = true
}

output "trust" {
  value = {
    ca = {
      algorithm       = tls_private_key.trusted-ca.algorithm
      private_key_pem = tls_private_key.trusted-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.trusted-ca.cert_pem
    }
  }
  sensitive = true
}

output "letsencrypt" {
  value = {
    private_key_pem         = tls_private_key.letsencrypt-prod.private_key_pem
    staging_private_key_pem = tls_private_key.letsencrypt-staging.private_key_pem
    username                = var.letsencrypt_username
  }
  sensitive = true
}

output "minio" {
  value = {
    access_key_id     = random_password.minio-access-key-id.result
    secret_access_key = random_password.minio-secret-access-key.result
  }
  sensitive = true
}