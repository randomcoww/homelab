locals {
  jfs_mount_path   = "/var/run/code/home"
  code_server_port = 8080
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.code_server)[1]
  manifests = merge(module.jfs.chart.manifests, {
    "templates/secret.yaml"  = module.secret.manifest
    "templates/service.yaml" = module.service.manifest
    "templates/ingress.yaml" = module.ingress.manifest
  })
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    for i, config in var.extra_configs :
    "${i}-${basename(config.path)}" => config.content
  }
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
        name       = "code-server"
        port       = local.code_server_port
        protocol   = "TCP"
        targetPort = local.code_server_port
      },
    ]
  }
}

module "ingress" {
  source             = "../../../modules/ingress"
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
          port    = local.code_server_port
          path    = "/"
        },
      ]
    },
  ]
}

module "jfs" {
  source = "../statefulset_jfs"
  ## jfs settings
  minio_endpoint          = var.minio_endpoint
  minio_bucket            = var.minio_bucket
  minio_litestream_prefix = "litestream"
  minio_jfs_prefix        = "jfs"
  minio_access_key_id     = var.minio_access_key_id
  minio_secret_access_key = var.minio_secret_access_key
  jfs_mount_path          = local.jfs_mount_path
  jfs_capacity_gb         = 80
  images = {
    jfs        = var.images.jfs
    litestream = var.images.litestream
  }
  ##
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.code_server
        args = [
          "bash",
          "-c",
          <<-EOF
          set -e
          update-ca-trust

          until mountpoint ${local.jfs_mount_path}; do
          sleep 1
          done

          useradd $USER -d $HOME -m -u $UID
          usermod -G wheel $USER

          mkdir -p $HOME $XDG_RUNTIME_DIR
          chown $UID:$UID $HOME $XDG_RUNTIME_DIR

          runuser -p -u $USER -- bash <<EOT
          cd $HOME
          exec /opt/openvscode-server/bin/openvscode-server \
            --host 0.0.0.0 \
            --port ${local.code_server_port} \
            --without-connection-token
          EOT
          EOF
        ]
        env = concat([
          for _, e in var.extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
          ], [
          {
            name  = "USER"
            value = var.user
          },
          {
            name  = "UID"
            value = tostring(var.uid)
          },
          {
            name  = "HOME"
            value = "${local.jfs_mount_path}/${var.user}"
          },
          {
            name  = "XDG_RUNTIME_DIR"
            value = "/run/user/${var.uid}"
          },
        ])
        volumeMounts = concat([
          for i, config in var.extra_configs :
          {
            name      = "config"
            mountPath = config.path
            subPath   = "${i}-${basename(config.path)}"
          }
        ], var.extra_volume_mounts)
        ports = [
          {
            containerPort = local.code_server_port
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.code_server_port
            path   = "/"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.code_server_port
            path   = "/"
          }
        }
        securityContext = var.security_context
        resources       = var.resources
      },
    ]
    volumes = concat([
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
    ], var.extra_volumes)
    dnsConfig = {
      options = [
        {
          name  = "ndots"
          value = "1"
        },
      ]
    }
  }
}