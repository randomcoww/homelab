locals {
  home_path       = "/home/steam"
  steamapp_path   = "/var/tmp/steamcmd"
  persistent_path = "/var/lib/steamcmd/mnt"
  uid             = 1000
  gid             = 1000
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.s3fs)[1]
  manifests = merge(module.s3fs.chart.manifests, {
    "templates/service.yaml" = module.service.manifest
    "templates/secret.yaml"  = module.secret.manifest
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
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
  }
  spec = {
    type              = "LoadBalancer"
    loadBalancerIP    = var.service_ip
    loadBalancerClass = var.loadbalancer_class_name
    ports = concat([
      for name, port in var.tcp_ports :
      {
        name       = name
        port       = port
        protocol   = "TCP"
        targetPort = port
      }
      ], [
      for name, port in var.udp_ports :
      {
        name       = name
        port       = port
        protocol   = "UDP"
        targetPort = port
      }
    ])
  }
}

module "s3fs" {
  source = "../statefulset_s3fs"
  ## s3 config
  s3_endpoint          = var.s3_endpoint
  s3_bucket            = var.s3_bucket
  s3_prefix            = "$(POD_NAME)"
  s3_access_key_id     = var.s3_access_key_id
  s3_secret_access_key = var.s3_secret_access_key
  s3_mount_path        = local.persistent_path
  s3_mount_extra_args = concat([
    "uid=${local.uid}",
    "gid=${local.gid}",
  ], var.s3_mount_extra_args)
  images = {
    s3fs = var.images.s3fs
  }
  ##
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  spec = {
    volumeClaimTemplates = [
      {
        metadata = {
          name = "steamapp"
        }
        spec = {
          accessModes = [
            "ReadWriteOnce",
          ]
          storageClassName = var.storage_class_name
          resources = {
            requests = {
              storage = "20Gi"
            }
          }
        }
      },
    ]
  }
  template_spec = {
    initContainers = [
      {
        name  = "${var.name}-steamcmd"
        image = var.images.steamcmd
        command = [
          "bash",
          "-c",
          <<-EOF
          set -xe

          exec steamcmd \
            +force_install_dir $STEAMAPP_PATH \
            +login anonymous \
            +app_update "${var.steamapp_id}" \
            -beta "public" validate +quit
          EOF
        ]
        env = [
          {
            name  = "HOME"
            value = local.home_path
          },
          {
            name  = "STEAMAPP_PATH"
            value = local.steamapp_path
          },
        ]
        volumeMounts = [
          {
            name      = "steamapp"
            mountPath = local.steamapp_path
          },
        ]
        securityContext = {
          runAsUser  = local.uid
          runAsGroup = local.gid
          fsGroup    = local.gid
        }
      },
    ]
    containers = [
      {
        name    = var.name
        image   = var.images.steamcmd
        command = var.command
        env = concat([
          {
            name = "POD_IP"
            valueFrom = {
              fieldRef = {
                fieldPath = "status.podIP"
              }
            }
          },
          {
            name  = "HOME"
            value = local.home_path
          },
          {
            name  = "STEAMAPP_PATH"
            value = local.steamapp_path
          },
          {
            name  = "PERSISTENT_PATH"
            value = local.persistent_path
          },
          ],
          [
            for _, e in var.extra_envs :
            {
              name  = e.name
              value = tostring(e.value)
            }
        ])
        ports = concat([
          for name, port in var.tcp_ports :
          {
            containerPort = port
            protocol      = "TCP"
          }
          ], [
          for name, port in var.udp_ports :
          {
            containerPort = port
            protocol      = "UDP"
          }
        ])
        volumeMounts = concat([
          {
            name      = "steamapp"
            mountPath = local.steamapp_path
          },
          ], [
          for i, config in var.extra_configs :
          {
            name      = "config"
            mountPath = config.path
            subPath   = "${i}-${basename(config.path)}"
          }
        ], var.extra_volume_mounts)
        readinessProbe = var.healthcheck
        livenessProbe  = var.healthcheck
        resources      = var.resources
        securityContext = merge({
          runAsUser  = local.uid
          runAsGroup = local.gid
          fsGroup    = local.gid
        }, var.security_context)
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
  }
}