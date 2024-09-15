locals {
  ports = {
    syncthing = 22000
  }
  sync_name           = "${var.name}-syncthing"
  syncthing_home_path = "/var/lib/syncthing"

  syncthing_conainer = {
    name  = local.sync_name
    image = var.images.syncthing
    command = [
      "sh",
      "-c",
      <<-EOF
      set -e
      mkdir -p ${local.syncthing_home_path}
      cp \
        /tmp/config.xml \
        /tmp/cert.pem \
        /tmp/key.pem \
        ${local.syncthing_home_path}

      exec syncthing \
        --home ${local.syncthing_home_path}
      EOF
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
        name      = "syncthing-config"
        mountPath = "/tmp/config.xml"
        subPath   = "config.xml"
      },
      {
        name        = "syncthing-config"
        mountPath   = "/tmp/cert.pem"
        subPathExpr = "cert-$(POD_NAME)"
      },
      {
        name        = "syncthing-config"
        mountPath   = "/tmp/key.pem"
        subPathExpr = "key-$(POD_NAME)"
      },
      ], [
      for i, path in var.sync_data_paths :
      {
        name      = "sync-path-${i}"
        mountPath = path
      }
    ])
    ports = [
      {
        containerPort = local.ports.syncthing
      },
    ]
  }

  manifests = {
    "templates/secret-syncthing.yaml"  = module.secret.manifest
    "templates/service-syncthing.yaml" = module.service.manifest
    "templates/statefulset.yaml"       = module.statefulset.manifest
  }
}

module "metadata" {
  source    = "../metadata"
  name      = var.name
  namespace = var.namespace
  release   = var.release
  manifests = var.sync_replicas > 0 ? merge(local.manifests, {
    "templates/statefulset-syncthing.aml" = module.statefulset-syncthing.manifest
  }) : local.manifests
}

module "syncthing-config" {
  source = "../syncthing_config"
  hostnames = concat([
    for i in range(var.replicas) :
    "${var.name}-${i}.${local.sync_name}.${var.namespace}"
    ], [
    for i in range(var.sync_replicas) :
    "${local.sync_name}-${i}.${local.sync_name}.${var.namespace}"
  ])
  syncthing_home_path = local.syncthing_home_path
  sync_data_paths     = var.sync_data_paths
  ports = {
    syncthing_peer = local.ports.syncthing
  }
}

module "secret" {
  source  = "../secret"
  name    = local.sync_name
  app     = var.name
  release = var.release
  data = merge({
    "config.xml" = module.syncthing-config.config
    }, {
    for peer in module.syncthing-config.peers :
    "cert-${split(".", peer.hostname)[0]}" => peer.cert
    }, {
    for peer in module.syncthing-config.peers :
    "key-${split(".", peer.hostname)[0]}" => peer.key
  })
}

module "service" {
  source  = "../service"
  name    = local.sync_name
  app     = var.name
  release = var.release
  spec = {
    type      = "ClusterIP"
    clusterIP = "None"
    ports = [
      {
        name       = "syncthing"
        port       = local.ports.syncthing
        protocol   = "TCP"
        targetPort = local.ports.syncthing
      },
    ]
  }
}

module "statefulset-syncthing" {
  source      = "../statefulset"
  name        = local.sync_name
  app         = var.name
  release     = var.release
  replicas    = var.sync_replicas
  affinity    = var.sync_affinity
  tolerations = var.sync_tolerations
  annotations = {
    "checksum/${module.secret.name}" = sha256(module.secret.manifest)
  }
  spec = {
    serviceName     = local.sync_name
    minReadySeconds = 30
  }
  template_spec = {
    containers = [
      local.syncthing_conainer,
    ]
    ports = [
      {
        containerPort = local.ports.syncthing
        protocol      = "TCP"
      },
    ]
    volumes = concat([
      for i, path in var.sync_data_paths :
      {
        name = "sync-path-${i}"
        emptyDir = {
          medium = "Memory"
        }
      }
      ], [
      {
        name = "syncthing-config"
        secret = {
          secretName = module.secret.name
        }
      },
    ])
  }
}

module "statefulset" {
  source      = "../statefulset"
  name        = var.name
  app         = var.name
  release     = var.release
  replicas    = var.replicas
  affinity    = var.affinity
  tolerations = var.tolerations
  annotations = merge({
    "checksum/${module.secret.name}" = sha256(module.secret.manifest)
  }, var.annotations)
  spec = merge(var.spec, {
    serviceName     = local.sync_name
    minReadySeconds = 30
  })
  template_spec = merge(var.template_spec, {
    initContainers = concat([
      merge(local.syncthing_conainer, {
        restartPolicy = "Always"
      }),
    ], lookup(var.template_spec, "initContainers", []))
    containers = [
      for _, container in lookup(var.template_spec, "containers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          for i, path in var.sync_data_paths :
          {
            name      = "sync-path-${i}"
            mountPath = path
          }
        ])
      })
    ]
    volumes = concat(lookup(var.template_spec, "volumes", []), [
      for i, path in var.sync_data_paths :
      {
        name = "sync-path-${i}"
        emptyDir = {
          medium = "Memory"
        }
      }
      ], [
      {
        name = "syncthing-config"
        secret = {
          secretName = module.secret.name
        }
      },
    ])
    ports = concat(lookup(var.template_spec, "ports", []), [
      {
        containerPort = local.ports.syncthing
        protocol      = "TCP"
      },
    ])
  })
}