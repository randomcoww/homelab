locals {
  # https://docs.lizardbyte.dev/projects/sunshine/en/latest/about/advanced_usage.html#port
  base_port = 47989
  tcp_ports = {
    https = local.base_port - 5
    http  = local.base_port
    rtsp  = local.base_port + 21
  }
  udp_ports = {
    video   = local.base_port + 9
    control = local.base_port + 10
    audio   = local.base_port + 11
    mic     = local.base_port + 13
  }
  web_port               = local.base_port + 1
  home_path              = "/home/${var.user}"
  sunshine_apps_file     = "/etc/sunshine/apps.json"
  sunshine_prep_cmd_file = "/usr/local/bin/sunshine-prep-cmd.sh"
  gamescope_cmd_file     = "/usr/local/bin/gamescope-launch"
}

# bypassed through nginx - no need to expose
resource "random_password" "username" {
  length  = 16
  special = false
}

# bypassed through nginx - no need to expose
resource "random_password" "password" {
  length  = 16
  special = false
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/secret.yaml"      = module.secret.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/web-service.yaml" = module.web-service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    for i, config in var.extra_configs :
    "${i}-${basename(config.path)}" => config.content
    }, {
    USERNAME = random_password.username.result
    PASSWORD = random_password.password.result
    basename(local.sunshine_apps_file) = jsonencode({
      apps = [
        {
          name       = "Desktop"
          image-path = "desktop.png"
          prep-cmd = [
            {
              do = local.sunshine_prep_cmd_file
            },
          ]
        },
      ],
      env = {
        PATH = "$(PATH):$(HOME)/.local/bin" # needed for some client connection step
      }
    })
    basename(local.sunshine_prep_cmd_file) = <<-EOF
    #!/bin/bash
    set -xe

    wlr-randr \
      --output HEADLESS-1 \
      --custom-mode $${SUNSHINE_CLIENT_WIDTH}x$${SUNSHINE_CLIENT_HEIGHT}@$${SUNSHINE_CLIENT_FPS}
    EOF
    basename(local.gamescope_cmd_file)     = <<-EOF
    #!/bin/bash
    set -e

    gamescope -f \
      -W $(wlr-randr --json | jq '.[] | select(.name == "HEADLESS-1") | .modes[] | select(.current == true).width') \
      -H $(wlr-randr --json | jq '.[] | select(.name == "HEADLESS-1") | .modes[] | select(.current == true).height') \
      --immediate-flips --force-grab-cursor --rt --hdr-enabled $@
    EOF
  })
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
    loadBalancerIP    = "0.0.0.0"
    loadBalancerClass = var.loadbalancer_class_name
    ports = concat([
      for name, port in local.tcp_ports :
      {
        name       = name
        port       = port
        protocol   = "TCP"
        targetPort = port
      }
      ], [
      for name, port in local.udp_ports :
      {
        name       = name
        port       = port
        protocol   = "UDP"
        targetPort = port
      }
    ])
  }
}

module "web-service" {
  source  = "../../../modules/service"
  name    = "${var.name}-web"
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "web"
        port       = local.web_port
        protocol   = "TCP"
        targetPort = local.web_port
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
  annotations = merge(var.nginx_ingress_annotations, {
    "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTPS"
    "nginx.ingress.kubernetes.io/configuration-snippet" = <<-EOF
    proxy_set_header Authorization "Basic ${base64encode("${random_password.username.result}:${random_password.password.result}")}";
    EOF
  })
  rules = [
    {
      host = var.ingress_hostname
      paths = [
        {
          service = module.web-service.name
          port    = local.web_port
          path    = "/"
        },
      ]
    },
  ]
}

module "statefulset" {
  source   = "../../../modules/statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  replicas = 1
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    volumeClaimTemplates = [
      {
        metadata = {
          name = "home"
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
    resources = {
      requests = {
        memory = "2Gi"
      }
      limits = {
        memory = "16Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.sunshine_desktop
        args = [
          "bash",
          "-c",
          <<-EOF
          set -e

          ## User ##

          useradd $USER -d $HOME -m -u $UID
          usermod -G video,input,render,dbus,seat $USER

          mkdir -p $HOME $XDG_RUNTIME_DIR
          chown $UID:$UID $HOME $XDG_RUNTIME_DIR

          ## Udev ##

          /lib/systemd/systemd-udevd &

          ## Seatd ##

          seatd -u $USER &

          runuser -p -u $USER -- bash <<EOT
          set -e
          cd $HOME
          cp -r /etc/skel/. $HOME/

          ## Pulseaudio ##

          pulseaudio \
            --log-level=0 \
            --daemonize=true \
            --disallow-exit=true \
            --log-target=stderr \
            --exit-idle-time=-1

          ## Sway ##

          sway &

          ## Sunshine ##

          sunshine --creds $SUNSHINE_USERNAME $SUNSHINE_PASSWORD

          while ! wlr-randr >/dev/null 2>&1; do
          sleep 1
          done
          exec sunshine \
            origin_web_ui_allowed=wan \
            port=${local.base_port} \
            file_apps=${local.sunshine_apps_file} \
            upnp=off
          EOT
          EOF
        ]
        env = concat([
          {
            name = "SUNSHINE_USERNAME"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "USERNAME"
              }
            }
          },
          {
            name = "SUNSHINE_PASSWORD"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "PASSWORD"
              }
            }
          },
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
            value = local.home_path
          },
          {
            name  = "XDG_RUNTIME_DIR"
            value = "/run/user/${var.uid}"
          },
          ], [
          for _, e in var.extra_envs :
          {
            name  = tostring(e.name)
            value = tostring(e.value)
          }
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
            mountPath = local.home_path
          },
          {
            name      = "dev-input"
            mountPath = "/dev/input"
          },
          {
            name      = "dev-shm"
            mountPath = "/dev/shm"
          },
          {
            name      = "dev-dri"
            mountPath = "/dev/dri"
          },
          {
            name      = "config"
            mountPath = local.sunshine_apps_file
            subPath   = basename(local.sunshine_apps_file)
          },
          {
            name      = "commands"
            mountPath = local.sunshine_prep_cmd_file
            subPath   = basename(local.sunshine_prep_cmd_file)
          },
          {
            name      = "commands"
            mountPath = local.gamescope_cmd_file
            subPath   = basename(local.gamescope_cmd_file)
          },
        ], var.extra_volume_mounts)
        ports = concat([
          for name, port in local.tcp_ports :
          {
            containerPort = port
            protocol      = "TCP"
          }
          ], [
          for name, port in local.udp_ports :
          {
            containerPort = port
            protocol      = "UDP"
          }
        ])
        livenessProbe = {
          tcpSocket = {
            port = local.base_port
          }
          timeoutSeconds = 2
        }
        readinessProbe = {
          tcpSocket = {
            port = local.base_port
          }
        }
        startupProbe = {
          tcpSocket = {
            port = local.base_port
          }
          failureThreshold = 6
        }
        resources = {
          # use /dev/dri in place of gpu resource to share gpu with another container
          requests = {
            "squat.ai/ntsync" = 1
          }
          limits = {
            "squat.ai/ntsync" = 1
          }
        }
        securityContext = var.security_context
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
        name = "commands"
        secret = {
          secretName  = module.secret.name
          defaultMode = 493
        }
      },
      {
        name = "dev-input"
        hostPath = {
          path = "/dev/input"
        }
      },
      {
        name = "dev-dri"
        hostPath = {
          path = "/dev/dri"
        }
      },
      {
        name = "dev-shm"
        emptyDir = {
          medium    = "Memory"
          sizeLimit = "1Gi"
        }
      },
    ], var.extra_volumes)
  }
}