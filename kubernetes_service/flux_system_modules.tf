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

module "cert-manager-cloudflare-secret" {
  source  = "../modules/secret"
  name    = "cloudflare-token"
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    token = data.terraform_remote_state.sr.outputs.cloudflare_dns_api_token
  })
}

module "cert-manager-issuer-acme-prod-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuers.acme_prod
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.private_key_pem)
  })
}

module "cert-manager-issuer-acme-staging-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuers.acme_staging
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.staging_private_key_pem)
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

# minio

resource "tls_private_key" "minio" {
  algorithm   = data.terraform_remote_state.sr.outputs.trust.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "minio" {
  private_key_pem = tls_private_key.minio.private_key_pem

  subject {
    common_name = local.endpoints.minio.name
  }
  ip_addresses = [
    "127.0.0.1",
    local.services.minio.ip,
    local.services.cluster_minio.ip,
  ]
  dns_names = concat([
    "localhost",
    local.endpoints.minio.name,
    local.endpoints.minio.service,
    ], [
    for i, _ in range(local.minio_replicas) :
    "${local.endpoints.minio.name}-${i}.${local.endpoints.minio.name}-svc.${local.endpoints.minio.namespace}.svc"
  ])
}

resource "tls_locally_signed_cert" "minio" {
  cert_request_pem   = tls_cert_request.minio.cert_request_pem
  ca_private_key_pem = data.terraform_remote_state.sr.outputs.trust.ca.private_key_pem
  ca_cert_pem        = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
    "server_auth",
  ]
}

module "minio-tls" {
  source  = "../modules/secret"
  name    = "${local.endpoints.minio.name}-tls"
  app     = local.endpoints.minio.name
  release = "0.1.0"
  data = {
    "tls.crt" = tls_locally_signed_cert.minio.cert_pem
    "tls.key" = tls_private_key.minio.private_key_pem
    "ca.crt"  = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  }
}

module "minio-metrics-proxy" {
  source  = "../modules/configmap"
  name    = "${local.endpoints.minio.name}-proxy"
  app     = local.endpoints.minio.name
  release = "0.1.0"
  data = {
    "nginx-proxy.conf" = <<-EOF
    proxy_request_buffering off;
    proxy_buffering off;
    proxy_cache off;

    server {
      listen ${local.service_ports.metrics};
      location /minio/metrics/v3 {
        proxy_pass https://127.0.0.1:${local.service_ports.minio};

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }
    }
    EOF
  }
}