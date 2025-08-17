locals {
  config_path = "/var/lib/dragonfly/flags.txt"
  peer_name   = "${var.name}-peer"
  peers = {
    for i, _ in range(var.replicas) :
    "${var.name}-${i}" => "${var.name}-${i}.${local.peer_name}.${var.namespace}"
  }
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.dragonfly)[1]
  manifests = {
    "templates/secret.yaml"       = module.secret.manifest
    "templates/statefulset.yaml"  = module.statefulset.manifest
    "templates/service.yaml"      = module.service.manifest
    "templates/service-peer.yaml" = module.service-peer.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    for hostname, _ in local.peers :
    "${basename(local.config_path)}-${hostname}" => <<-EOF
    bind=0.0.0.0
    port=${var.ports.redis}
    ${var.extra_configs}
    ${join("\n", [
    for k, v in local.peers :
    "replicaof=${v}:${var.ports.rediss}" if hostname != k
])}
    EOF
},
{
  basename(local.cert_path)    = chomp(tls_locally_signed_cert.dragonfly.cert_pem)
  basename(local.key_path)     = chomp(tls_private_key.dragonfly.private_key_pem)
  basename(local.ca_cert_path) = chomp(var.ca.cert_pem)
})
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "redis"
        port       = var.ports.redis
        protocol   = "TCP"
        targetPort = var.ports.redis
      },
    ]
  }
}

module "service-peer" {
  source  = "../../../modules/service"
  name    = local.peer_name
  app     = var.name
  release = var.release
  spec = {
    type                     = "ClusterIP"
    clusterIP                = "None"
    publishNotReadyAddresses = true
    ports = [
      {
        name       = "rediss"
        port       = var.ports.rediss
        protocol   = "TCP"
        targetPort = var.ports.rediss
      },
    ]
  }
}

module "statefulset" {
  source   = "../../../modules/statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  replicas = var.replicas
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    serviceName          = local.peer_name
    minReadySeconds      = 30
    volumeClaimTemplates = var.volume_claim_templates
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.dragonfly
        args = [
          "--flagfile=${local.config_path}",
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
        ports = [
          {
            containerPort = var.ports.redis
          },
        ]
        volumeMounts = concat([
          {
            name        = "dragonfly-secret"
            mountPath   = local.config_path
            subPathExpr = "${basename(local.config_path)}-$(POD_NAME)"
          },
        ], var.extra_volume_mounts)
        readinessProbe = {
          exec = {
            command = [
              "sh",
              "/usr/local/bin/healthcheck.sh"
            ]
          }
          initialDelaySeconds = 10
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 3
          successThreshold    = 1
        }
        livenessProbe = {
          exec = {
            command = [
              "sh",
              "/usr/local/bin/healthcheck.sh"
            ]
          }
          initialDelaySeconds = 10
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 3
          successThreshold    = 1
        }
      },
    ]
    volumes = concat([
      {
        name = "dragonfly-secret"
        secret = {
          secretName = module.secret.name
        }
      },
    ], var.extra_volumes)
    dnsConfig = {
      options = [
        {
          name  = "ndots"
          value = "5"
        },
      ]
    }
  }
}