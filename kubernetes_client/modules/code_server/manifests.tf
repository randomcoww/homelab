locals {
  jfs_db_path    = "/var/lib/jfs/${var.name}.db"
  code_home_path = "/home/${var.user}"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.code_server)[1]
  manifests = {
    "templates/secret.yaml"      = module.secret.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    ssh_known_hosts = join("\n", var.ssh_known_hosts)
    "litestream.yml" = yamlencode({
      dbs = [
        {
          path = local.jfs_db_path
          replicas = [
            {
              type                     = "s3"
              bucket                   = var.jfs_minio_bucket
              path                     = basename(local.jfs_db_path)
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
    })
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

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    initContainers = [
      {
        name  = "${var.name}-init"
        image = var.images.litestream
        args = [
          "restore",
          "-if-replica-exists",
          "-config",
          "/etc/litestream.yml",
          local.jfs_db_path,
        ]
        volumeMounts = [
          {
            name      = "jfs-data"
            mountPath = dirname(local.jfs_db_path)
          },
          {
            name      = "secret"
            mountPath = "/etc/litestream.yml"
            subPath   = "litestream.yml"
          },
        ]
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.code_server
        env = concat([
          {
            name  = "USER"
            value = var.user
          },
          {
            name  = "HOME"
            value = local.code_home_path
          },
          {
            name  = "UID"
            value = tostring(var.uid)
          },
          {
            name  = "CODE_PORT"
            value = tostring(var.ports.code_server)
          },
          {
            name  = "JFS_RESOURCE_NAME"
            value = var.name
          },
          {
            name  = "JFS_MINIO_BUCKET"
            value = "http://${var.jfs_minio_endpoint}/${var.jfs_minio_bucket}"
          },
          {
            name  = "JFS_DB_PATH"
            value = local.jfs_db_path
          },
          {
            name  = "JFS_MINIO_ACCESS_KEY_ID"
            value = var.jfs_minio_access_key_id
          },
          {
            name  = "JFS_MINIO_SECRET_ACCESS_KEY"
            value = var.jfs_minio_secret_access_key
          },
          ], [
          for k, v in var.code_server_extra_envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ])
        volumeMounts = [
          {
            name      = "jfs-data"
            mountPath = dirname(local.jfs_db_path)
          },
          {
            name      = "secret"
            mountPath = "/etc/ssh/ssh_known_hosts"
            subPath   = "ssh_known_hosts"
            readOnly  = true
          },
        ]
        ports = [
          {
            containerPort = var.ports.code_server
          },
        ]
        resources = merge({
          limits = {
            "github.com/fuse" = 1
          }
        }, var.code_server_resources)
        securityContext = {
          privileged = true
        }

      },
      {
        name  = "${var.name}-backup"
        image = var.images.litestream
        args = [
          "replicate",
          "-config",
          "/etc/litestream.yml",
        ]
        volumeMounts = [
          {
            name      = "jfs-data"
            mountPath = dirname(local.jfs_db_path)
          },
          {
            name      = "secret"
            mountPath = "/etc/litestream.yml"
            subPath   = "litestream.yml"
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
      {
        name = "jfs-data"
        emptyDir = {
          medium = "Memory"
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