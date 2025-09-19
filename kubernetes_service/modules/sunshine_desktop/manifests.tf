locals {
  # https://docs.lizardbyte.dev/projects/sunshine/en/latest/about/advanced_usage.html#port
  base_port = 47989
  tcp_ports = {
    https = local.base_port - 5
    http  = local.base_port
    web   = local.base_port + 1
    rtsp  = local.base_port + 21
  }
  udp_ports = {
    video   = local.base_port + 9
    control = local.base_port + 10
    audio   = local.base_port + 11
    mic     = local.base_port + 13
  }
  home_path          = "/home/${var.user}"
  sunshine_apps_path = "/etc/sunshine/apps.json"
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
  app_version = split(":", var.images.sunshine_desktop)[1]
  manifests = {
    "templates/secret.yaml"      = module.secret.manifest
    "templates/service.yaml"     = module.service.manifest
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
    basename(local.sunshine_apps_path) = jsonencode({
      apps = [
        {
          name       = "Desktop"
          image-path = "desktop.png"
          prep-cmd = [
            {
              do = "sunshine-prep-cmd.sh"
            },
          ]
        }
      ],
      env = {
        PATH = "$(PATH):$(HOME)/.local/bin"
      }
    })
  })
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
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
      host = var.admin_hostname
      paths = [
        {
          service = module.service.name
          port    = local.tcp_ports.web
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
    runtimeClassName = "nvidia-cdi"
    containers = [
      {
        name  = var.name
        image = var.images.sunshine_desktop
        args = [
          "bash",
          "-c",
          <<EOF
          set -e
          update-ca-trust

          ## User ##

          useradd $USER -d $HOME -m -u $UID
          usermod -G video,input,render,dbus,seat $USER

          mkdir -p $HOME $XDG_RUNTIME_DIR
          chown $UID:$UID $HOME $XDG_RUNTIME_DIR

          ## Driver ##

          mkdir -p $HOME/nvidia
          targetarch=$(arch)
          driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader --id=0)
          driver_file=$HOME/nvidia/NVIDIA-Linux-$targetarch-$driver_version.run

          NVIDIA_DRIVER_BASE_URL=$${NVIDIA_DRIVER_BASE_URL:-https://us.download.nvidia.com/XFree86/$${targetarch/x86_64/Linux-x86_64}}
          curl -fsSL --remove-on-error --skip-existing -o "$driver_file" \
            $NVIDIA_DRIVER_BASE_URL/$driver_version/NVIDIA-Linux-$targetarch-$driver_version.run

          chmod +x "$driver_file"
          "$driver_file" \
            --silent \
            --accept-license \
            --skip-depmod \
            --skip-module-unload \
            --no-kernel-modules \
            --no-kernel-module-source \
            --no-nouveau-check \
            --no-nvidia-modprobe \
            --no-systemd \
            --no-wine-files \
            --no-x-check \
            --no-dkms \
            --no-distro-scripts \
            --no-rpms \
            --no-backup \
            --no-check-for-alternate-installs \
            --no-libglx-indirect \
            --no-install-libglvnd

          ## Udev ##

          /lib/systemd/systemd-udevd &

          ## Seatd ##

          seatd -u $USER &

          runuser -p -u $USER -- bash <<EOT
          set -e
          cd $HOME

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
            file_apps=${local.sunshine_apps_path} \
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
            name  = e.name
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
            name      = "config"
            mountPath = local.sunshine_apps_path
            subPath   = basename(local.sunshine_apps_path)
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
        readinessProbe = {
          tcpSocket = {
            port = local.base_port
          }
        }
        livenessProbe = {
          tcpSocket = {
            port = local.base_port
          }
        }
        resources       = var.resources
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
        name = "dev-input"
        hostPath = {
          path = "/dev/input"
        }
      },
      {
        name = "dev-shm"
        emptyDir = {
          medium    = "Memory"
          sizeLimit = "2Gi"
        }
      },
    ], var.extra_volumes)
  }
}