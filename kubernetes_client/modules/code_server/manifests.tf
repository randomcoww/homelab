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
    ssh_known_hosts            = join("\n", var.ssh_known_hosts)
    "containers-override.conf" = <<-EOF
    [containers]
    userns = "host"
    ipcns = "host"
    cgroupns = "host"
    cgroups = "disabled"
    log_driver = "k8s-file"
    volumes = [
      "/proc:/proc",
    ]
    default_sysctls = []

    [engine]
    cgroup_manager = "cgroupfs"
    events_logger = "none"
    runtime = "crun"
    EOF

    "storage.conf" = <<-EOF
    [storage]
    driver = "overlay"
    runroot = "/run/containers/storage"
    graphroot = "/var/lib/containers/storage"
    rootless_storage_path = "/tmp/containers-user-$UID/storage"

    [storage.options]
    additionalimagestores = []
    pull_options = {enable_partial_images = "true", use_hard_links = "false", ostree_repos = ""}

    [storage.options.overlay]
    ignore_chown_errors = "true"
    mountopt = "nodev,fsync=0"
    EOF
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

          HOME=${local.code_home_path} \
          exec s6-setuidgid ${var.user} \
          code-server \
            --auth=none \
            --bind-addr=0.0.0.0:${var.ports.code_server}
          EOF
        ]
        env = [
          for k, v in var.code_server_extra_envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ]
        volumeMounts = [
          {
            name      = "secret"
            mountPath = "/etc/ssh/ssh_known_hosts"
            subPath   = "ssh_known_hosts"
          },
          {
            name      = "secret"
            mountPath = "/etc/containers/containers.conf.d/10-pinp.conf"
            subPath   = "containers-override.conf"
          },
          {
            name      = "secret"
            mountPath = "/etc/containers/storage.conf"
            subPath   = "storage.conf"
          },
        ]
        ports = [
          {
            containerPort = var.ports.code_server
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