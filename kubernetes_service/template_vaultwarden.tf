locals {
  vaultwarden_db_user    = "vaultwarden"
  vaultwarden_db_service = "yb-tserver-service"
  vaultwarden_ns         = "vaultwarden"
}

resource "random_string" "vaultwarden-db-password" {
  length  = 32
  special = false
}

resource "helm_release" "vaultwarden-db" {
  name             = "vaultwarden-db"
  repository       = "https://charts.yugabyte.com"
  chart            = "yugabyte"
  namespace        = local.vaultwarden_ns
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  version          = "2024.2.3"
  max_history      = 2
  values = [
    yamlencode({
      # overrides https://github.com/yugabyte/charts/blob/master/stable/yugabyte/values.yaml
      replicas = {
        master  = 3
        tserver = 3
      }
      domainName = local.domains.kubernetes
      resource = {
      }
      serviceEndpoints = [
        {
          name = local.vaultwarden_db_service
          type = "LoadBalancer"
          annotations = {
            "kube-vip.io/loadbalancerIPs" = "0.0.0.0"
          }
          app = "yb-tserver"
          ports = {
            tcp-ysql-port = local.service_ports.yugabyte_ysql
          },
        },
      ]
      authCredentials = {
        ysql = {
          user     = local.vaultwarden_db_user
          password = random_string.vaultwarden-db-password.result
        }
      }
    }),
  ]
}

module "vaultwarden" {
  source    = "./modules/vaultwarden"
  name      = "vaultwarden"
  namespace = local.vaultwarden_ns
  release   = "0.1.14"
  replicas  = 1
  images = {
    vaultwarden = local.container_images.vaultwarden
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
    DATABASE_URL             = "postgresql://${local.vaultwarden_db_user}:${urlencode(random_string.vaultwarden-db-password.result)}@${local.vaultwarden_db_service}.${local.vaultwarden_ns}:${local.service_ports.yugabyte_ysql}/vaultwarden"
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  depends_on = [
    helm_release.vaultwarden-db,
  ]
}