resource "tls_private_key" "lldap-db-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "lldap-db-ca" {
  private_key_pem = tls_private_key.lldap-db-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = "Cockroach"
    organization = "Cockroach"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

module "lldap-db" {
  source                   = "./modules/cockroachdb"
  cluster_service_endpoint = local.kubernetes_services.lldap_db.fqdn
  release                  = "0.1.0"
  replicas                 = 3
  images = {
    cockroachdb = local.container_images.cockroachdb
  }
  ports = {
    cockroachdb = local.service_ports.cockroachdb
  }
  ca = {
    algorithm       = tls_private_key.lldap-db-ca.algorithm
    private_key_pem = tls_private_key.lldap-db-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.lldap-db-ca.cert_pem
  }
  extra_configs = {
    store = "/data"
  }
  extra_volume_mounts = [
    {
      name      = "data"
      mountPath = "/data"
    },
  ]
  volume_claim_templates = [
    {
      metadata = {
        name = "data"
      }
      spec = {
        accessModes = [
          "ReadWriteOnce",
        ]
        resources = {
          requests = {
            storage = "4Gi"
          }
        }
        storageClassName = "local-path"
      }
    },
  ]
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
  ca               = data.terraform_remote_state.sr.outputs.lldap.ca
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

  litestream_s3_resource             = data.terraform_remote_state.sr.outputs.s3.lldap.resource
  litestream_s3_access_key_id        = data.terraform_remote_state.sr.outputs.s3.lldap.access_key_id
  litestream_s3_secret_access_key    = data.terraform_remote_state.sr.outputs.s3.lldap.secret_access_key
  litestream_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  litestream_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  litestream_minio_bucket            = local.minio_buckets.litestream.name
  litestream_minio_endpoint          = "${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
}