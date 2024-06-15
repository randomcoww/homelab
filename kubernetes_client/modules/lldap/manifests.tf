locals {
  db_path             = "/data/users.db"
  base_path           = "/var/lib/lldap"
  storage_secret_path = "${local.base_path}/private_key"
  ldaps_cert_path     = "${local.base_path}/cert.pem"
  ldaps_key_path      = "${local.base_path}/key.pem"
  extra_envs = merge(var.extra_envs, {
    LLDAP_LDAP_PORT           = var.ports.lldap
    LLDAP_HTTP_PORT           = var.ports.lldap_http
    LLDAP_LDAPS_OPTIONS__PORT = var.ports.lldap_ldaps

    LLDAP_DATABASE_URL             = "sqlite://${local.db_path}?mode=rwc"
    LLDAP_LDAPS_OPTIONS__CERT_FILE = local.ldaps_cert_path
    LLDAP_LDAPS_OPTIONS__KEY_FILE  = local.ldaps_key_path
    LLDAP_KEY_FILE                 = local.storage_secret_path

    LLDAP_HTTP_HOST    = "0.0.0.0"
    LLDAP_LDAP_HOST    = "0.0.0.0"
    LLDAP_HTTP_URL     = "https://${var.service_hostname}"
    LLDAP_LDAP_BASE_DN = "dc=${join(",dc=", slice(compact(split(".", var.service_hostname)), 1, length(compact(split(".", var.service_hostname)))))}"
  })
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.lldap)[1]
  manifests = {
    "templates/service.yaml"           = module.service.manifest
    "templates/ingress.yaml"           = module.ingress.manifest
    "templates/secret.yaml"            = module.secret.manifest
    "templates/statefulset.yaml"       = module.litestream-statefulset.statefulset
    "templates/secret-litestream.yaml" = module.litestream-statefulset.secret
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    storage-secret   = var.storage_secret
    "ldaps-cert.pem" = chomp(tls_locally_signed_cert.lldap.cert_pem)
    "ldaps-key.pem"  = chomp(tls_private_key.lldap.private_key_pem)
    }, {
    for k, v in local.extra_envs :
    tostring(k) => tostring(v)
  })
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "ldaps"
        port       = var.ports.lldap_ldaps
        protocol   = "TCP"
        targetPort = var.ports.lldap_ldaps
      },
      {
        name       = "http"
        port       = var.ports.lldap_http
        protocol   = "TCP"
        targetPort = var.ports.lldap_http
      },
    ]
  }
}

module "ingress" {
  source             = "../ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = module.service.name
          port    = var.ports.lldap_http
          path    = "/"
        }
      ]
    },
  ]
}

module "litestream-statefulset" {
  source = "../statefulset_litestream"
  ## litestream settings
  litestream_image = var.images.litestream
  litestream_config = {
    dbs = [
      {
        path = local.db_path
        replicas = [
          {
            url               = "s3://${var.s3_db_resource}/${basename(local.db_path)}"
            access-key-id     = var.s3_access_key_id
            secret-access-key = var.s3_secret_access_key
          }
        ]
      }
    ]
  }
  sqlite_path = local.db_path
  ##
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    containers = [
      {
        name  = var.name
        image = var.images.lldap
        args = [
          "run",
          "-c",
          "/dev/null"
        ]
        env = [
          for k, v in local.extra_envs :
          {
            name = tostring(k)
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = tostring(k)
              }
            }
          }
        ]
        volumeMounts = [
          {
            name      = "secret"
            mountPath = local.storage_secret_path
            subPath   = "storage-secret"
          },
          {
            name      = "secret"
            mountPath = local.ldaps_cert_path
            subPath   = "ldaps-cert.pem"
          },
          {
            name      = "secret"
            mountPath = local.ldaps_key_path
            subPath   = "ldaps-key.pem"
          },
        ]
      },
    ]
    volumes = [
      {
        name = "secret"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}
