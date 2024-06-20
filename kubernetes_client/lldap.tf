module "lldap" {
  source    = "./modules/lldap"
  name      = local.kubernetes_services.lldap.name
  namespace = local.kubernetes_services.lldap.namespace
  release   = "0.1.0"
  images = {
    lldap      = local.container_images.lldap
    litestream = local.container_images.litestream
  }
  ports = {
    lldap_ldaps = local.service_ports.lldap
  }
  ca                       = data.terraform_remote_state.sr.outputs.lldap.ca
  cluster_service_endpoint = local.kubernetes_services.lldap.fqdn
  service_hostname         = local.kubernetes_ingress_endpoints.lldap_http
  storage_secret           = data.terraform_remote_state.sr.outputs.lldap.storage_secret
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
  s3_db_resource            = data.terraform_remote_state.sr.outputs.s3.lldap.resource
  s3_access_key_id          = data.terraform_remote_state.sr.outputs.s3.lldap.access_key_id
  s3_secret_access_key      = data.terraform_remote_state.sr.outputs.s3.lldap.secret_access_key
}