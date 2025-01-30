output "s3_bucket" {
  value = {
    for name, res in local.s3_resources :
    name => {
      resource          = res.resource
      bucket            = res.bucket
      access_key_id     = aws_iam_access_key.s3[name].id
      secret_access_key = aws_iam_access_key.s3[name].secret
      aws_region        = local.aws_region
    }
  }
  sensitive = true
}

output "route53_hosted_zone" {
  value = {
    access_key_id     = aws_iam_access_key.hosted_zone.id
    secret_access_key = aws_iam_access_key.hosted_zone.secret
  }
  sensitive = true
}

output "tailscale_auth_key" {
  value     = tailscale_tailnet_key.auth.key
  sensitive = true
}

# etcd

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

# kubernetes

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

output "matchbox" {
  value = {
    ca = {
      algorithm       = tls_private_key.matchbox-ca.algorithm
      private_key_pem = tls_private_key.matchbox-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem
    }
  }
  sensitive = true
}

output "authelia" {
  value = {
    storage_secret         = random_password.authelia-storage-secret.result
    session_encryption_key = random_password.authelia-session-encryption-key.result
    jwt_token              = random_password.authelia-jwt-token.result
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

output "lldap" {
  value = {
    user           = random_password.lldap-user.result
    password       = random_password.lldap-password.result
    storage_secret = random_password.lldap-storage-secret.result
    jwt_token      = random_password.lldap-jwt-token.result
  }
  sensitive = true
}