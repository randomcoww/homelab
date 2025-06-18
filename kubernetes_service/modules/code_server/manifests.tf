module "metadata" {
  source      = "../../../modules/metadata"
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
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    for i, config in var.extra_configs :
    "${i}-${basename(config.path)}" => config.content
  }
}

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
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
  source             = "../../../modules/ingress"
  name               = var.name
  namespace          = var.namespace
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
        },
      ]
    },
  ]
}

module "statefulset" {
  source    = "../../../modules/statefulset"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    hostNetwork = true
    dnsPolicy   = "ClusterFirstWithHostNet"
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
          useradd ${var.user} -d ${var.home_path} -m -u ${var.uid}
          usermod -G wheel ${var.user}

          exec s6-setuidgid ${var.user} \
          code-server \
            --auth=none \
            --disable-telemetry \
            --disable-update-check \
            --bind-addr=0.0.0.0:${var.ports.code_server}
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
            name  = "HOME"
            value = var.home_path
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
          ], [
          {
            name      = "home"
            mountPath = var.home_path
          },
        ], var.extra_volume_mounts)
        ports = [
          {
            containerPort = var.ports.code_server
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.code_server
            path   = "/healthz"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.code_server
            path   = "/healthz"
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
      {
        name = "home"
        hostPath = {
          path = var.home_path
          type = "Directory"
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