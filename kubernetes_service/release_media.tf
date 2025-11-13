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
  resources = {
    requests = {
      memory = "4Gi"
    }
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

  minio_endpoint         = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_data_bucket      = "ebooks"
  minio_bucket           = "kavita"
  minio_mount_extra_args = []
  minio_access_secret    = local.minio_users.kavita.secret
  ca_bundle_configmap    = local.kubernetes.ca_bundle_configmap
}

# Webdav

module "webdav-ebooks" {
  source    = "./modules/webdav"
  name      = local.endpoints.webdav_ebooks.name
  namespace = local.endpoints.webdav_ebooks.namespace
  release   = "0.1.0"
  replicas  = 1
  images = {
    rclone = local.container_images.rclone
  }
  service_hostname   = local.endpoints.webdav_ebooks.ingress
  ingress_class_name = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "ebooks"
  minio_access_secret = local.minio_users.kavita.secret
  ca_bundle_configmap = local.kubernetes.ca_bundle_configmap
}

# Sunshine desktop

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
  ]
  extra_envs = [
    {
      name  = "NVIDIA_DRIVER_CAPABILITIES"
      value = "all"
    },
    {
      name  = "__NV_PRIME_RENDER_OFFLOAD"
      value = 1
    },
    {
      name  = "__GLX_VENDOR_LIBRARY_NAME"
      value = "nvidia"
    },
    {
      name  = "TZ"
      value = local.timezone
    },
  ]
  resources = {
    requests = {
      memory           = "16Gi"
      "nvidia.com/gpu" = 1
      "amd.com/gpu"    = 1
    }
    limits = {
      memory           = "16Gi"
      "nvidia.com/gpu" = 1
      "amd.com/gpu"    = 1
    }
  }
  security_context = {
    privileged = true # TODO: Revisit - currently privileged to make libinput work
  }
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"
  ingress_hostname        = local.endpoints.sunshine_desktop.ingress
  service_hostname        = local.endpoints.sunshine_desktop.service
  ingress_class_name      = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(
    local.nginx_ingress_annotations_common, {
      "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })
}