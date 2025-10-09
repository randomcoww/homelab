locals {
  config_file = "/etc/litestream/config.yaml"
}

module "metadata" {
  source    = "../../../modules/metadata"
  name      = var.name
  namespace = var.namespace
  release   = var.release
  manifests = {
    "templates/statefulset.yaml"       = module.statefulset.manifest
    "templates/secret-litestream.yaml" = module.secret.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = "${var.name}-litestream"
  app     = var.app
  release = var.release
  data = {
    "config.yaml" = yamlencode(var.litestream_config)
  }
}

module "statefulset" {
  source   = "../../../modules/statefulset"
  name     = var.name
  app      = var.app
  release  = var.release
  replicas = var.replicas
  annotations = merge({
    "checksum/${module.secret.name}" = sha256(module.secret.manifest)
  }, var.annotations)
  affinity    = var.affinity
  tolerations = var.tolerations
  spec        = var.spec
  template_spec = merge(var.template_spec, {
    initContainers = concat([
      {
        name  = "${var.name}-litestream-restore"
        image = var.images.litestream
        args = [
          "restore",
          "-if-db-not-exists",
          # "-if-replica-exists", # TODO: not working in 0.5.0
          "-config",
          local.config_file,
          var.sqlite_path,
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
          {
            name = "AWS_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "AWS_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "litestream-config"
            mountPath = local.config_file
            subPath   = "config.yaml"
          },
          {
            name      = "litestream-data"
            mountPath = dirname(var.sqlite_path)
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            subPath   = "ca.crt"
            readOnly  = true
          },
        ]
      },
      {
        name          = "${var.name}-litestream-replicate"
        image         = var.images.litestream
        restartPolicy = "Always"
        args = [
          "replicate",
          "-config",
          local.config_file,
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
          {
            name = "AWS_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "AWS_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "litestream-config"
            mountPath = local.config_file
            subPath   = "config.yaml"
          },
          {
            name      = "litestream-data"
            mountPath = dirname(var.sqlite_path)
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            subPath   = "ca.crt"
            readOnly  = true
          },
        ]
      },
      ], [
      for _, container in lookup(var.template_spec, "initContainers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "litestream-data"
            mountPath = dirname(var.sqlite_path)
          },
        ])
      })
    ])
    containers = [
      for _, container in lookup(var.template_spec, "containers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "litestream-data"
            mountPath = dirname(var.sqlite_path)
          },
        ])
      })
    ]
    volumes = concat(lookup(var.template_spec, "volumes", []), [
      {
        name = "litestream-config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "ca-trust-bundle"
        configMap = {
          name = var.ca_bundle_configmap
        }
      },
    ])
  })
}