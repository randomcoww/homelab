locals {
  code_home_path    = "/mnt/home/${var.user}"
  jfs_metadata_path = "/var/lib/jfs/${var.name}.db"
  user_data_path    = "${local.code_home_path}/.local/share/${var.name}"
  config_path       = "${local.user_data_path}/config.yaml"
  ports = {
    code_server = 8080
  }
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
    "templates/statefulset.yaml" = module.statefulset-jfs.statefulset
    "templates/secret-jfs.yaml"  = module.statefulset-jfs.secret
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
        port       = local.ports.code_server
        protocol   = "TCP"
        targetPort = local.ports.code_server
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
          port    = local.ports.code_server
          path    = "/"
        }
      ]
    },
  ]
}

module "statefulset-jfs" {
  source = "../statefulset_jfs"
  ## jfs settings
  jfs_metadata_endpoint       = var.jfs_metadata_endpoint
  jfs_metadata_ca             = var.jfs_metadata_ca
  jfs_image                   = var.images.jfs
  jfs_mount_path              = dirname(local.code_home_path)
  jfs_minio_resource          = "http://${var.jfs_minio_endpoint}/${var.jfs_minio_resource}"
  jfs_minio_access_key_id     = var.jfs_minio_access_key_id
  jfs_minio_secret_access_key = var.jfs_minio_secret_access_key
  tls_cn                      = "root"
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
          "with-contenv",
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
            --disable-telemetry \
            --disable-update-check \
            --config=${local.config_path} \
            --user-data-dir=${local.user_data_path} \
            --bind-addr=0.0.0.0:${local.ports.code_server}
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
            containerPort = local.ports.code_server
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.code_server
            path   = "/healthz"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.code_server
            path   = "/healthz"
          }
        }
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