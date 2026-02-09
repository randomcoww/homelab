# Kavita

module "kavita" {
  source    = "./modules/kavita"
  name      = local.endpoints.kavita.name
  namespace = local.endpoints.kavita.namespace
  release   = "0.1.0"
  replicas  = 1
  images = {
    kavita     = local.container_images.kavita
    mountpoint = local.container_images.mountpoint
    litestream = local.container_images.litestream
  }
  extra_configs = {
    OpenIdConnectSettings = {
      Authority    = "https://${local.endpoints.authelia.ingress}"
      ClientId     = random_string.authelia-oidc-client-id["kavita"].result
      Secret       = random_password.authelia-oidc-client-secret["kavita"].result
      CustomScopes = []
      Enabled      = true
    }
  }
  ingress_hostname   = local.endpoints.kavita.ingress
  ingress_class_name = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_data_bucket   = "ebooks"
  minio_bucket        = "kavita"
  minio_access_secret = local.minio_users.kavita.secret
}

# Navidrome

module "navidrome" {
  source    = "./modules/navidrome"
  name      = local.endpoints.navidrome.name
  namespace = local.endpoints.navidrome.namespace
  release   = "0.1.0"
  replicas  = 1
  images = {
    navidrome  = local.container_images.navidrome
    mountpoint = local.container_images.mountpoint
    litestream = local.container_images.litestream
  }
  ingress_hostname   = local.endpoints.navidrome.ingress
  ingress_class_name = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(
    local.nginx_ingress_annotations_common,
    local.nginx_ingress_annotations_authelia, {
      "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })
  extra_configs = {
    ND_EXTAUTH_TRUSTEDSOURCES = join(",", [
      local.networks.kubernetes_pod.prefix,
    ])
    ND_ENABLEUSEREDITING = false
    TZ                   = local.timezone
  }

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_data_bucket   = "music"
  minio_bucket        = "navidrome"
  minio_access_secret = local.minio_users.navidrome.secret
}

# Sunshine desktop
/*
module "sunshine-desktop" {
  source    = "./modules/sunshine_desktop"
  name      = local.endpoints.sunshine_desktop.name
  namespace = local.endpoints.sunshine_desktop.namespace
  release   = "0.1.0"
  images = {
    sunshine_desktop = local.container_images.sunshine_desktop
  }
  user               = "sunshine"
  uid                = 10000
  storage_class_name = "local-path"
  extra_configs = [
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
  extra_envs = [
    {
      name  = "TZ"
      value = local.timezone
    },
    {
      name  = "WLR_DRM_NO_MODIFIERS"
      value = 1
    },
    {
      name  = "WLR_DRM_NO_ATOMIC"
      value = 1
    },
    {
      name  = "PROTON_ENABLE_HDR"
      value = 1
    },
    {
      name  = "PROTON_ENABLE_WAYLAND"
      value = 1
    },
    {
      name  = "PROTON_FSR4_UPGRADE"
      value = 1
    },
    {
      name  = "AMD_VULKAN_ICD"
      value = "RADV"
    },
    {
      name  = "MESA_SHADER_CACHE_MAX_SIZE"
      value = "12G"
    },
    {
      name  = "AMD_USERQ"
      value = 1
    },
    {
      name  = "ENABLE_LAYER_MESA_ANTI_LAG"
      value = 1
    },
  ]
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "amd.com/gpu.cu-count"
                operator = "Gt"
                values = [
                  "31",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  security_context = {
    privileged = true # TODO: Revisit - currently privileged to make libinput work
  }
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"
  ingress_hostname        = local.endpoints.sunshine_desktop.ingress
  service_hostname        = local.endpoints.sunshine_desktop.service
  ingress_class_name      = local.endpoints.ingress_nginx_internal.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.ca_internal
  })
}
*/