locals {
  ports = {
    syncthing = 22000
  }
  sync_name           = "${var.name}-syncthing"
  sync_app            = "${var.app}-syncthing"
  syncthing_home_path = "/var/lib/syncthing"
}

module "metadata" {
  source    = "../../../modules/metadata"
  name      = var.name
  namespace = var.namespace
  release   = var.release
  manifests = {
    "templates/secret-syncthing.yaml"  = module.secret.manifest
    "templates/service-syncthing.yaml" = module.service.manifest
    "templates/statefulset.yaml"       = module.statefulset.manifest
  }
}

module "syncthing-config" {
  source = "../syncthing_config"
  hostnames = [
    for i in range(var.replicas) :
    "${var.name}-${i}.${local.sync_name}.${var.namespace}"
  ]
  syncthing_home_path = local.syncthing_home_path
  sync_data_paths     = var.sync_data_paths
  ports = {
    syncthing_peer = local.ports.syncthing
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = local.sync_name
  app     = var.app
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
  source  = "../../../modules/service"
  name    = local.sync_name
  app     = var.app
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

module "statefulset" {
  source      = "../../../modules/statefulset"
  name        = var.name
  app         = var.app
  release     = var.release
  replicas    = var.replicas
  affinity    = var.affinity
  tolerations = var.tolerations
  labels = merge(var.labels, {
    syncthing-app = var.app
  })
  annotations = merge({
    "checksum/${module.secret.name}" = sha256(module.secret.manifest)
  }, var.annotations)
  spec = merge(var.spec, {
    serviceName     = local.sync_name
    minReadySeconds = 30
  })
  template_spec = merge(var.template_spec, {
    initContainers = concat([
      {
        name          = local.sync_name
        image         = var.images.syncthing
        restartPolicy = "Always"
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
      },
      ], [
      for _, container in lookup(var.template_spec, "initContainers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          for i, path in var.sync_data_paths :
          {
            name      = "sync-path-${i}"
            mountPath = path
          }
        ])
      })
    ])
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