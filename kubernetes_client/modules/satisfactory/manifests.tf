locals {
  config_path = "/var/lib/satisfactory"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.satisfactory_server)[1]
  manifests = {
    "templates/configmap.yaml"   = module.configmap.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
  }
  spec = {
    type = "LoadBalancer"
    externalIPs = [
      var.service_ip,
    ]
    ports = [
      {
        name       = "beacon"
        port       = var.ports.beacon
        protocol   = "UDP"
        targetPort = var.ports.beacon
      },
      {
        name       = "game"
        port       = var.ports.game
        protocol   = "UDP"
        targetPort = var.ports.game
      },
      {
        name       = "query"
        port       = var.ports.query
        protocol   = "UDP"
        targetPort = var.ports.query
      },
    ]
  }
}

module "configmap" {
  source  = "../configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data    = var.config_overrides
}

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  spec = {
    containers = [
      {
        name  = var.name
        image = var.images.satisfactory_server
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
          },
          {
            name      = "overrides"
            mountPath = "${local.config_path}/overrides"
            readOnly  = true
          },
        ]
        ports = [
          {
            containerPort = var.ports.beacon
            protocol      = "UDP"
          },
          {
            containerPort = var.ports.game
            protocol      = "UDP"
          },
          {
            containerPort = var.ports.query
            protocol      = "UDP"
          },
        ]
        env = concat([
          {
            name  = "SERVERBEACONPORT"
            value = tostring(var.ports.beacon)
          },
          {
            name  = "SERVERGAMEPORT"
            value = tostring(var.ports.game)
          },
          {
            name  = "SERVERQUERYPORT"
            value = tostring(var.ports.query)
          },
          ], [
          for k, v in var.extra_envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ])
        resources = var.resources
      },
    ]
    volumes = [
      {
        name = "overrides"
        configMap = {
          name = var.name
        }
      },
    ]
  }
  volume_claim_templates = [
    {
      metadata = {
        name = "config"
      }
      spec = {
        accessModes = var.storage_access_modes
        resources = {
          requests = {
            storage = var.volume_claim_size
          }
        }
        storageClassName = var.storage_class
      }
    },
  ]
}