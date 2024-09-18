resource "tls_private_key" "lldap-ca" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "tls_self_signed_cert" "lldap-ca" {
  private_key_pem = tls_private_key.lldap-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = "lldap"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

resource "minio_s3_bucket" "lldap" {
  bucket        = "lldap"
  force_destroy = false
  depends_on = [
    helm_release.minio,
  ]
}

resource "minio_iam_user" "lldap" {
  name          = "lldap"
  force_destroy = true
}

resource "minio_iam_policy" "lldap" {
  name = "lldap"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.lldap.arn,
          "${minio_s3_bucket.lldap.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "lldap" {
  user_name   = minio_iam_user.lldap.id
  policy_name = minio_iam_policy.lldap.id
}

module "lldap" {
  source                   = "./modules/lldap"
  cluster_service_endpoint = local.kubernetes_services.lldap.fqdn
  release                  = "0.1.0"
  images = {
    lldap      = local.container_images.lldap
    litestream = local.container_images.litestream
  }
  ports = {
    lldap_ldaps = local.service_ports.lldap
  }
  ca = {
    algorithm       = tls_private_key.lldap-ca.algorithm
    private_key_pem = tls_private_key.lldap-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.lldap-ca.cert_pem
  }
  service_hostname = local.kubernetes_ingress_endpoints.lldap_http
  storage_secret   = data.terraform_remote_state.sr.outputs.lldap.storage_secret
  extra_configs = {
    LLDAP_VERBOSE                             = true
    LLDAP_JWT_SECRET                          = data.terraform_remote_state.sr.outputs.lldap.jwt_token
    LLDAP_LDAP_USER_DN                        = data.terraform_remote_state.sr.outputs.lldap.user
    LLDAP_LDAP_USER_PASS                      = data.terraform_remote_state.sr.outputs.lldap.password
    LLDAP_SMTP_OPTIONS__ENABLE_PASSWORD_RESET = true
    LLDAP_SMTP_OPTIONS__SERVER                = var.smtp.host
    LLDAP_SMTP_OPTIONS__PORT                  = var.smtp.port
    LLDAP_SMTP_OPTIONS__SMTP_ENCRYPTION       = "STARTTLS"
    LLDAP_SMTP_OPTIONS__USER                  = var.smtp.username
    LLDAP_SMTP_OPTIONS__PASSWORD              = var.smtp.password
    LLDAP_LDAPS_OPTIONS__ENABLED              = true
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.lldap.id
  minio_access_key_id     = minio_iam_user.lldap.id
  minio_secret_access_key = minio_iam_user.lldap.secret
  minio_litestream_prefix = "$POD_NAME/litestream"
}