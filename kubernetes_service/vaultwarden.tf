resource "minio_s3_bucket" "vaultwarden" {
  bucket        = "vaultwarden"
  force_destroy = false
}

resource "minio_iam_user" "vaultwarden" {
  name          = "vaultwarden"
  force_destroy = true
}

resource "minio_iam_policy" "vaultwarden" {
  name = "vaultwarden"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.vaultwarden.arn,
          "${minio_s3_bucket.vaultwarden.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "vaultwarden" {
  user_name   = minio_iam_user.vaultwarden.id
  policy_name = minio_iam_policy.vaultwarden.id
}

module "vaultwarden" {
  source    = "./modules/vaultwarden"
  name      = "vaultwarden"
  namespace = "vaultwarden"
  release   = "0.1.14"
  images = {
    vaultwarden = local.container_images.vaultwarden
    litestream  = local.container_images.litestream
  }
  service_hostname = local.kubernetes_ingress_endpoints.vaultwarden
  extra_configs = {
    SENDS_ALLOWED            = false
    EMERGENCY_ACCESS_ALLOWED = false
    PASSWORD_HINTS_ALLOWED   = false
    SIGNUPS_ALLOWED          = false
    INVITATIONS_ALLOWED      = true
    DISABLE_ADMIN_TOKEN      = true
    SMTP_USERNAME            = var.smtp.username
    SMTP_FROM                = var.smtp.username
    SMTP_PASSWORD            = var.smtp.password
    SMTP_HOST                = var.smtp.host
    SMTP_PORT                = var.smtp.port
    SMTP_FROM_NAME           = "Vaultwarden"
    SMTP_SECURITY            = "starttls"
    SMTP_AUTH_MECHANISM      = "Plain"
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx_external
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations

  s3_resource          = data.terraform_remote_state.sr.outputs.s3.vaultwarden.resource
  s3_access_key_id     = data.terraform_remote_state.sr.outputs.s3.vaultwarden.access_key_id
  s3_secret_access_key = data.terraform_remote_state.sr.outputs.s3.vaultwarden.secret_access_key

  minio_endpoint          = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.vaultwarden.id
  minio_access_key_id     = minio_iam_user.vaultwarden.id
  minio_secret_access_key = minio_iam_user.vaultwarden.secret
  minio_litestream_prefix = "$POD_NAME/litestream"
}