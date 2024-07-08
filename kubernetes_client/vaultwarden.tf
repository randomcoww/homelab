
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
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations

  litestream_s3_resource             = data.terraform_remote_state.sr.outputs.s3.vaultwarden.resource
  litestream_s3_access_key_id        = data.terraform_remote_state.sr.outputs.s3.vaultwarden.access_key_id
  litestream_s3_secret_access_key    = data.terraform_remote_state.sr.outputs.s3.vaultwarden.secret_access_key
  litestream_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  litestream_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  litestream_minio_bucket            = local.minio_buckets.litestream.name
  litestream_minio_endpoint          = "${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
}