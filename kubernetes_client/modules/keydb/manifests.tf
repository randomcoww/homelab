locals {
  base_path = "/var/lib/keydb"

  cert_path        = "${local.base_path}/keydb.crt"
  key_path         = "${local.base_path}/keydb.key"
  client_cert_path = "${local.base_path}/client.crt"
  client_key_path  = "${local.base_path}/client.key"
  ca_cert_path     = "${local.base_path}/ca.crt"
  config_path      = "/etc/keydb.conf"
  socket_path      = "/tmp/keydb.sock"
  name             = split(".", var.cluster_service_endpoint)[0]
  namespace        = split(".", var.cluster_service_endpoint)[1]

  peers = {
    for i, _ in range(var.replicas) :
    "${local.name}-${i}" => "${local.name}-${i}.${var.cluster_service_endpoint}"
  }
}

module "metadata" {
  source      = "../metadata"
  name        = local.name
  namespace   = local.namespace
  release     = var.release
  app_version = split(":", var.images.keydb)[1]
  manifests = {
    "templates/secret.yaml"       = module.secret.manifest
    "templates/configmap.yaml"    = module.configmap.manifest
    "templates/statefulset.yaml"  = module.statefulset.manifest
    "templates/service.yaml"      = module.service.manifest
    "templates/service-peer.yaml" = module.service-peer.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = local.name
  app     = local.name
  release = var.release
  data = {
    basename(local.cert_path)        = chomp(tls_locally_signed_cert.keydb.cert_pem)
    basename(local.key_path)         = chomp(tls_private_key.keydb.private_key_pem)
    basename(local.client_cert_path) = chomp(tls_locally_signed_cert.keydb-client.cert_pem)
    basename(local.client_key_path)  = chomp(tls_private_key.keydb-client.private_key_pem)
    basename(local.ca_cert_path)     = chomp(var.ca.cert_pem)
  }
}

module "configmap" {
  source  = "../configmap"
  name    = local.name
  app     = local.name
  release = var.release
  data = {
    for hostname, peer in local.peers :
    "${basename(local.config_path)}-${hostname}" => <<-EOF
    bind 0.0.0.0
    port 0
    unixsocket ${local.socket_path}
    tls-port ${var.ports.keydb}
    tls-cert-file ${local.cert_path}
    tls-key-file ${local.key_path}
    tls-client-cert-file ${local.client_cert_path}
    tls-client-key-file ${local.client_key_path}
    tls-ca-cert-file ${local.ca_cert_path}
    tls-replication yes
    tls-cluster yes
    tls-protocols "TLSv1.3"
    tls-ciphersuites TLS_CHACHA20_POLY1305_SHA256
    active-replica yes
    multi-master yes
    appendonly yes
    ${var.extra_config}
    ${join("\n", [
    for k, v in local.peers :
    "replicaof ${v} ${var.ports.keydb}" if hostname != k
])}
    EOF
}
}

module "statefulset" {
  source            = "../statefulset"
  name              = local.name
  app               = local.name
  release           = var.release
  affinity          = var.affinity
  replicas          = var.replicas
  min_ready_seconds = 30
  annotations = {
    "checksum/secret"    = sha256(module.secret.manifest)
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  volume_claim_templates = var.volume_claim_templates
  spec = {
    containers = [
      {
        name  = local.name
        image = var.images.keydb
        args = [
          local.config_path,
        ]
        env = [
          {
            name = "POD_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.name"
              }
            }
          },
        ]
        volumeMounts = concat([
          {
            name      = "keydb-secret"
            mountPath = local.base_path
          },
          {
            name        = "keydb-config"
            mountPath   = local.config_path
            subPathExpr = "${basename(local.config_path)}-$(POD_NAME)"
          },
        ], var.extra_volume_mounts)
        readinessProbe = {
          exec = {
            command = [
              "keydb-cli",
              "-s",
              local.socket_path,
              "ping",
            ]
          }
          initialDelaySeconds = 15
          timeoutSeconds      = 15
        }
        livenessProbe = {
          exec = {
            command = [
              "keydb-cli",
              "-s",
              local.socket_path,
              "ping",
            ]
          }
          initialDelaySeconds = 15
          timeoutSeconds      = 15
        }
      },
    ]
    volumes = concat([
      {
        name = "keydb-secret"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "keydb-config"
        configMap = {
          name = module.configmap.name
        }
      },
    ], var.extra_volumes)
  }
}

module "service" {
  source  = "../service"
  name    = local.name
  app     = local.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "keydb"
        port       = var.ports.keydb
        protocol   = "TCP"
        targetPort = var.ports.keydb
      },
    ]
  }
}

module "service-peer" {
  source  = "../service"
  name    = "${local.name}-peer"
  app     = local.name
  release = var.release
  spec = {
    type                     = "ClusterIP"
    clusterIP                = "None"
    publishNotReadyAddresses = true
  }
}