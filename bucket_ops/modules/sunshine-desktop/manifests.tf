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
  proxy_web_port         = 8080
  home_path              = "/home/${var.user}"
  sunshine_apps_file     = "/etc/sunshine/apps.json"
  sunshine_prep_cmd_file = "/usr/local/bin/sunshine-prep-cmd.sh"

  configs = [
    # Limit sunshine application set to desktop
    {
      path = local.sunshine_apps_file
      content = jsonencode({
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
    },
    # Auto set resolution to match client
    {
      path    = local.sunshine_prep_cmd_file
      content = <<-EOF
      #!/bin/bash
      set -xe

      wlr-randr \
        --output HEADLESS-1 \
        --custom-mode $${SUNSHINE_CLIENT_WIDTH}x$${SUNSHINE_CLIENT_HEIGHT}@$${SUNSHINE_CLIENT_FPS}
      EOF
    },
    # Gamescope wrapper
    {
      path    = "/usr/local/bin/gamescope-launch"
      content = <<-EOF
      #!/bin/bash
      set -e

      gamescope -f \
        -W $(wlr-randr --json | jq '.[] | select(.name == "HEADLESS-1") | .modes[] | select(.current == true).width') \
        -H $(wlr-randr --json | jq '.[] | select(.name == "HEADLESS-1") | .modes[] | select(.current == true).height') \
        --immediate-flips --force-grab-cursor --rt --hdr-enabled $@
      EOF
    },
    {
      path    = "/usr/local/bin/ge-protonup"
      content = <<-EOF
      #!/bin/bash
      set -xe

      VERSION=$${VERSION:-$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep tag_name | cut -d '"' -f 4)}
      curl -fsSL --remove-on-error --skip-existing -O https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$VERSION/$VERSION-$(arch).tar.gz

      mkdir -p $HOME/.steam/steam/compatibilitytools.d/
      tar xzf $VERSION-$(arch).tar.gz -C $HOME/.steam/steam/compatibilitytools.d/
      EOF
    },
    {
      path    = "/etc/xdg/foot/foot.ini"
      content = <<-EOF
      font=monospace:size=14
      EOF
    },
    {
      path    = "/etc/tmux.conf"
      content = <<-EOF
      set -g history-limit 10000
      set -g mouse on
      set-option -s set-clipboard off
      bind-key -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -sel clip"
      EOF
    },
    {
      path    = "/etc/profile.d/tmux.sh"
      content = <<-EOF
      if [ -z "$TMUX" ]; then
        exec tmux new-session -A -s default
      fi
      EOF
    },
    {
      path    = "/etc/sway/config.d/sync"
      content = <<-EOF
      output * bg #000000 solid_color
      output * allow_tearing yes
      output * max_render_time off
      EOF
    },
  ]
  envs = merge({
    USER                       = var.user
    UID                        = var.uid
    HOME                       = local.home_path
    XDG_RUNTIME_DIR            = "/run/user/${var.uid}"
    PROTON_ENABLE_WAYLAND      = 1
    PROTON_ENABLE_HDR          = 1
    PROTON_USE_NTSYNC          = 1
    PROTON_FSR4_UPGRADE        = 1
    PROTON_NO_WM_DECORATION    = 1
    PROTON_LOCAL_SHADER_CACHE  = 1
    AMD_VULKAN_ICD             = "RADV"
    MESA_SHADER_CACHE_MAX_SIZE = "12G"
    AMD_USERQ                  = 1
    ENABLE_LAYER_MESA_ANTI_LAG = 1
    # WLR_RENDERER               = "vulkan" # TODO: track https://github.com/LizardByte/Sunshine/issues/4050 https://github.com/LizardByte/Sunshine/issues/5258
  }, var.extra_envs)
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

module "configmap" {
  source    = "../../../modules/configmap"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    for _, config in local.configs :
    replace(trimprefix(config.path, "/"), "/", "-") => config.content
  }
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    USERNAME     = random_password.username.result
    PASSWORD     = random_password.password.result
    "nginx.conf" = <<-EOF
    server {
      listen ${local.proxy_web_port};
      location / {
        proxy_ssl_verify off;
        proxy_ssl_server_name on;

        proxy_set_header Authorization "Basic ${base64encode("${random_password.username.result}:${random_password.password.result}")}";
        proxy_pass https://127.0.0.1:${local.web_port};

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }
    }
    EOF
  }
}

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
  }
  spec = {
    type = "LoadBalancer"
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
      ], [
      {
        name       = "web"
        port       = local.proxy_web_port
        protocol   = "TCP"
        targetPort = local.proxy_web_port
      },
    ])
  }
}

module "httproute" {
  source    = "../../../modules/httproute"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  spec = {
    parentRefs = [
      merge({
        kind = "Gateway"
      }, var.gateway_ref),
    ]
    hostnames = [
      var.ingress_hostname,
    ]
    rules = [
      {
        matches = [
          {
            path = {
              type  = "PathPrefix"
              value = "/"
            }
          },
        ]
        filters = [
          {
            type = "ExternalAuth"
            externalAuth = {
              protocol   = "HTTP"
              backendRef = var.auth_backend_ref
              http = {
                path = "/api/authz/ext-authz/"
                allowedHeaders = [
                  "accept",
                  "cookie",
                  "location",
                  "authorization",
                  "proxy-authorization",
                  "x-forwarded-proto",
                ]
                allowedResponseHeaders = [
                  "Remote-User",
                  "Remote-Email",
                  "Remote-Name",
                  "Remote-Groups",
                ]
              }
            }
          },
        ]
        backendRefs = [
          {
            name = module.service.name
            port = local.proxy_web_port
          },
        ]
      },
    ]
  }
}

module "statefulset" {
  source    = "../../../modules/statefulset"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  replicas  = 1
  affinity  = var.affinity
  annotations = {
    "checksum/secret"                     = sha256(module.secret.manifest)
    "checksum/configmap"                  = sha256(module.configmap.manifest)
    "secret.reloader.stakater.com/reload" = "${var.name}-ca-tls"
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
              storage = "120Gi"
            }
          }
        }
      },
    ]
  }
  template_spec = {
    resourceClaims = [
      {
        name              = "gpu"
        resourceClaimName = var.gpu_resource_claim
      },
    ]
    resources = {
      requests = {
        memory = "16Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = "${var.images.sunshine-desktop.repository}:${var.images.sunshine-desktop.tag}"
        args = [
          "bash",
          "-c",
          <<-EOF
          set -e

          ## User ##

          useradd $USER -d $HOME -m -u $UID
          usermod -G video,input,render,dbus $USER

          mkdir -p $HOME $XDG_RUNTIME_DIR
          chown $UID:$UID $HOME $XDG_RUNTIME_DIR

          ## Udev ##

          /lib/systemd/systemd-udevd &

          runuser -p -u $USER -- bash <<EOT
          set -e
          cd $HOME
          cp -r /etc/skel/. $HOME/

          ## dbus-daemon ##

          dbus-daemon --system

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
            encoder=vulkan \
            csrf_allowed_origins=https://${var.ingress_hostname} \
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
          ], [
          for k, v in local.envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ])
        volumeMounts = concat([
          {
            name      = "home"
            mountPath = local.home_path
          },
          {
            name      = "tls"
            mountPath = "${local.home_path}/.config/sunshine/credentials/cacert.pem" # auto-generated by sunshine unless passed in
            subPath   = "tls.crt"
          },
          {
            name      = "tls"
            mountPath = "${local.home_path}/.config/sunshine/credentials/cakey.pem" # auto-generated by sunshine unless passed in
            subPath   = "tls.key"
          },
          {
            name      = "dev-shm"
            mountPath = "/dev/shm"
          },
          {
            name      = "run-dbus"
            mountPath = "/run/dbus"
          },
          ], [
          for _, config in local.configs :
          {
            name      = "config"
            mountPath = config.path
            subPath   = replace(trimprefix(config.path, "/"), "/", "-")
          }
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
          claims = [
            {
              name = "gpu"
            },
          ]
          requests = {
            "devic.es/ntsync" = 1
            "devic.es/input"  = 1
            "devic.es/uinput" = 1
            "devic.es/tty"    = 1
          }
          limits = {
            "devic.es/ntsync" = 1
            "devic.es/input"  = 1
            "devic.es/uinput" = 1
            "devic.es/tty"    = 1
          }
        }
        securityContext = {
          privileged = true # TODO: Privileged to make libinput work https://github.com/squat/generic-device-plugin/issues/148
        }
      },
      {
        name          = "${var.name}-web-proxy"
        image         = "${var.images.nginx.repository}:${var.images.nginx.tag}"
        restartPolicy = "Always"
        ports = [
          {
            containerPort = local.proxy_web_port
          },
        ]
        volumeMounts = [
          {
            name      = "secret"
            mountPath = "/etc/nginx/conf.d/default.conf"
            subPath   = "nginx.conf"
          },
        ]
      },
    ]
    volumes = concat([
      {
        name = "secret"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "tls"
        secret = {
          secretName  = "${var.name}-ca-tls"
          defaultMode = 420
        }
      },
      {
        name = "config"
        configMap = {
          name        = module.configmap.name
          defaultMode = 493
        }
      },
      {
        name = "dev-shm"
        emptyDir = {
          medium    = "Memory"
          sizeLimit = "1Gi"
        }
      },
      {
        name = "run-dbus"
        emptyDir = {
          medium = "Memory"
        }
      },
    ], var.extra_volumes)
  }
}