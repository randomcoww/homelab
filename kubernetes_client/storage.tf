resource "tls_private_key" "jfs-redis-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "jfs-redis-ca" {
  private_key_pem = tls_private_key.jfs-redis-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = "redis"
    organization = "redis"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

module "jfs-redis" {
  source                   = "./modules/keydb"
  cluster_service_endpoint = local.kubernetes_services.jfs_redis.fqdn
  release                  = "0.1.0"
  replicas                 = 3
  images = {
    keydb = local.container_images.keydb
  }
  ports = {
    keydb = local.service_ports.redis
  }
  ca = {
    algorithm       = tls_private_key.jfs-redis-ca.algorithm
    private_key_pem = tls_private_key.jfs-redis-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.jfs-redis-ca.cert_pem
  }
  extra_configs = <<-EOF
  dir /data
  appendonly yes
  appendfsync always
  repl-diskless-sync yes
  EOF
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