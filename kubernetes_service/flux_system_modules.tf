# Load balancer

module "kube-vip" {
  source    = "./modules/kube_vip"
  name      = "kube-vip"
  namespace = "kube-system"
  images = {
    kube_vip = local.container_images_digest.kube_vip
  }
  ports = {
    apiserver        = local.host_ports.apiserver,
    kube_vip_metrics = local.host_ports.kube_vip_metrics,
    kube_vip_health  = local.host_ports.kube_vip_health,
  }
  bgp_as     = local.ha.bgp_as
  bgp_peeras = local.ha.bgp_as
  bgp_neighbor_ips = [
    for _, host in local.members.gateway :
    cidrhost(local.networks.service.prefix, host.netnum)
  ]
  apiserver_ip      = local.services.apiserver.ip
  service_interface = "phy-service"
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "node-role.kubernetes.io/control-plane"
                operator = "Exists"
              },
            ]
          },
        ]
      }
    }
  }
}

module "minio" {
  source    = "./modules/minio"
  name      = local.endpoints.minio.name
  namespace = local.endpoints.minio.namespace
  images = {
    nginx = local.container_images_digest.nginx
    minio = {
      repository = regex(local.container_image_regex, local.container_images.minio).depName
      tag        = regex(local.container_image_regex, local.container_images.minio).tag
    }
  }
  ports = {
    minio   = local.service_ports.minio
    metrics = local.service_ports.metrics
  }
  minio_credentials  = data.terraform_remote_state.sr.outputs.minio
  cluster_domain     = local.domains.kubernetes
  ca                 = data.terraform_remote_state.sr.outputs.trust.ca
  service_ip         = local.services.minio.ip
  cluster_service_ip = local.services.cluster_minio.ip
}

module "registry" {
  source    = "./modules/registry"
  name      = local.endpoints.registry.name
  namespace = local.endpoints.registry.namespace
  replicas  = 2
  images = {
    registry = local.container_images_digest.registry
  }
  ports = {
    registry = local.service_ports.registry
    metrics  = local.service_ports.metrics
  }
  ca                      = data.terraform_remote_state.sr.outputs.trust.ca
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_access_secret = local.minio_users.registry.secret
  service_ip          = local.services.registry.ip
  service_hostname    = local.endpoints.registry.service
  ui_ingress_hostname = local.endpoints.registry.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

# cert-manager

module "cert-manager-issuer-acme-prod-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuers.acme_prod
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.key"        = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.private_key_pem)
    cloudflare-token = data.terraform_remote_state.sr.outputs.cloudflare_dns_api_token
  })
}

module "cert-manager-issuer-ca-internal-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuers.ca_internal
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.crt" = chomp(data.terraform_remote_state.sr.outputs.trust.ca.cert_pem)
    "tls.key" = chomp(data.terraform_remote_state.sr.outputs.trust.ca.private_key_pem)
  })
}

# Generic device plugin

module "device-plugin" {
  source    = "./modules/device_plugin"
  name      = "device-plugin"
  namespace = "kube-system"
  images = {
    device_plugin = local.container_images_digest.device_plugin
  }
  ports = {
    device_plugin_metrics = local.service_ports.metrics
  }
  args = [
    "--device",
    yamlencode({
      name = "rfkill"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/rfkill"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "kvm"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/kvm"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "fuse"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/fuse"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "ntsync"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/ntsync"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "uinput"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/uinput"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "input"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/input"
              type = "Mount"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "tty"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/tty0"
            },
            {
              path = "/dev/tty1"
            },
          ]
        },
      ]
    }),
  ]
  kubelet_root_path = local.kubernetes.kubelet_root_path
}