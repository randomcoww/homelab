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

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    hostNetwork = true
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
          usermod \
            -G wheel \
            --add-subuids 100000-165535 \
            --add-subgids 100000-165535 \
            ${var.user}

          mkdir -p /home
          ln -s ${var.home_path} /home || true

          exec s6-setuidgid ${var.user} \
          code-server \
            --auth=none \
            --disable-telemetry \
            --disable-update-check \
            --bind-addr=0.0.0.0:${var.ports.code_server}
          EOF
        ]
        env = concat([
          for _, e in var.code_server_extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
          ], [
          {
            name  = "HOME"
            value = var.home_path
          },
        ])
        volumeMounts = concat([
          for i, config in var.code_server_extra_configs :
          {
            name      = "config"
            mountPath = config.path
            subPath   = "${i}-${basename(config.path)}"
          }
          ], [
          {
            name      = "home"
            mountPath = var.home_path
          }
        ], var.code_server_extra_volume_mounts)
        ports = [
          {
            containerPort = var.ports.code_server
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = var.ports.code_server
            path   = "/healthz"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = var.ports.code_server
            path   = "/healthz"
          }
        }
        securityContext = var.code_server_security_context
        resources       = var.code_server_resources
      },
    ]
    volumes = concat([
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
      ], [
      {
        name = "home"
        hostPath = {
          path = var.home_path
        }
      }
    ], var.code_server_extra_volumes)
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