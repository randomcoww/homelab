locals {
  code_home_path    = "/mnt/home/${var.user}"
  jfs_metadata_path = "/var/lib/jfs/${var.name}.db"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.code_server)[1]
  manifests = {
    "templates/secret.yaml"            = module.secret.manifest
    "templates/service.yaml"           = module.service.manifest
    "templates/ingress.yaml"           = module.ingress.manifest
    "templates/statefulset.yaml"       = module.statefulset-jfs.statefulset
    "templates/secret-litestream.yaml" = module.statefulset-jfs.secret
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    for i, config in var.code_server_extra_configs :
    "${i}-${basename(config.path)}" => config.content
  }
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
        name       = "code-server"
        port       = var.ports.code_server
        protocol   = "TCP"
        targetPort = var.ports.code_server
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
          port    = var.ports.code_server
          path    = "/"
        }
      ]
    },
  ]
}

module "statefulset-jfs" {
  source = "../statefulset_jfs"
  ## litestream settings
  litestream_image = var.images.litestream
  litestream_config = {
    dbs = [
      {
        path = local.jfs_metadata_path
        replicas = [
          {
            type                     = "s3"
            bucket                   = var.jfs_minio_bucket
            path                     = basename(local.jfs_metadata_path)
            endpoint                 = "http://${var.jfs_minio_endpoint}"
            access-key-id            = var.jfs_minio_access_key_id
            secret-access-key        = var.jfs_minio_secret_access_key
            retention                = "2m"
            retention-check-interval = "2m"
            sync-interval            = "500ms"
            snapshot-interval        = "1h"
          },
        ]
      },
    ]
  }
  sqlite_path = local.jfs_metadata_path

  ## jfs settings
  jfs_image                   = var.images.juicefs
  jfs_mount_path              = dirname(local.code_home_path)
  jfs_minio_resource          = "http://${var.jfs_minio_endpoint}/${var.jfs_minio_bucket}"
  jfs_minio_access_key_id     = var.jfs_minio_access_key_id
  jfs_minio_secret_access_key = var.jfs_minio_secret_access_key
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
        image = var.images.code_server
        args = [
          "bash",
          "-c",
          <<-EOF
          set -xe

          mountpoint ${dirname(local.code_home_path)}

          useradd ${var.user} -d ${local.code_home_path} -m -u ${var.uid}
          usermod \
            -G wheel \
            --add-subuids 100000-165535 \
            --add-subgids 100000-165535 \
            ${var.user}

          mkdir -p /run/user/${var.uid}
          chown ${var.user}:${var.user} /run/user/${var.uid}

          HOME=${local.code_home_path} \
          XDG_RUNTIME_DIR=/run/user/${var.uid} \
          %{~for _, e in var.code_server_extra_envs~}
          ${e.name}=${tostring(e.value)} \
          %{~endfor~}
          exec s6-setuidgid ${var.user} \
          code-server \
            --auth=none \
            --disable-telemetry \
            --bind-addr=0.0.0.0:${var.ports.code_server}
          EOF
        ]
        env = [
          for _, e in var.code_server_extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
        ]
        volumeMounts = [
          for i, config in var.code_server_extra_configs :
          {
            name      = "config"
            mountPath = config.path
            subPath   = "${i}-${basename(config.path)}"
          }
        ]
        ports = [
          {
            containerPort = var.ports.code_server
          },
        ]
        securityContext = var.code_server_security_context
        resources       = var.code_server_resources
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
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