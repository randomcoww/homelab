locals {
  authelia_oidc_clients_base = {
    open-webui = {
      client_name = "Open WebUI"
      scopes = [
        "openid",
        "email",
        "profile",
        "groups",
      ]
      require_pkce          = false
      pkce_challenge_method = ""
      redirect_uris = [
        "https://${local.endpoints.open_webui.ingress}/oauth/oidc/callback",
      ]
    }
    kavita = {
      client_name = "Kavita"
      scopes = [
        "openid",
        "email",
        "profile",
        "groups",
        "roles",
        "offline_access",
      ]
      redirect_uris = [
        "https://${local.endpoints.kavita.ingress}/signin-oidc",
      ]
      token_endpoint_auth_method = "client_secret_post"
    }
  }

  authelia_oidc_clients = {
    for k, v in local.authelia_oidc_clients_base :
    k => merge(v, {
      client_id     = random_string.authelia-oidc-client-id[k].result
      client_secret = random_password.authelia-oidc-client-secret[k].result
    })
  }
}

resource "random_string" "authelia-oidc-client-id" {
  for_each = local.authelia_oidc_clients_base

  length  = 32
  special = false
  upper   = false
}

resource "random_password" "authelia-oidc-client-secret" {
  for_each = local.authelia_oidc_clients_base

  length  = 32
  special = false
}

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

# auth

resource "tls_private_key" "lldap-ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "lldap-ca" {
  private_key_pem = tls_private_key.lldap-ca.private_key_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160
  is_ca_certificate     = true

  subject {
    common_name = "lldap"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

resource "random_password" "lldap-user" {
  length  = 30
  special = false
}

resource "random_password" "lldap-password" {
  length  = 30
  special = false
}

module "lldap" {
  source    = "./modules/lldap"
  name      = local.endpoints.lldap.name
  namespace = local.endpoints.lldap.namespace
  images = {
    lldap      = local.container_images_digest.lldap
    litestream = local.container_images_digest.litestream
  }
  ports = {
    ldaps = local.service_ports.ldaps
  }
  extra_configs = {
    LLDAP_VERBOSE                             = true
    LLDAP_LDAP_USER_DN                        = random_password.lldap-user.result
    LLDAP_LDAP_USER_PASS                      = random_password.lldap-password.result
    LLDAP_SMTP_OPTIONS__ENABLE_PASSWORD_RESET = true
    LLDAP_SMTP_OPTIONS__SERVER                = var.smtp.host
    LLDAP_SMTP_OPTIONS__PORT                  = var.smtp.port
    LLDAP_SMTP_OPTIONS__SMTP_ENCRYPTION       = "STARTTLS"
    LLDAP_SMTP_OPTIONS__USER                  = var.smtp.username
    LLDAP_SMTP_OPTIONS__PASSWORD              = var.smtp.password
    LLDAP_LDAPS_OPTIONS__ENABLED              = true
  }
  ca = {
    algorithm       = tls_private_key.lldap-ca.algorithm
    private_key_pem = tls_private_key.lldap-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.lldap-ca.cert_pem
  }

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "lldap"
  minio_access_secret = local.minio_users.lldap.secret

  service_hostname = local.endpoints.lldap.service_fqdn
  ingress_hostname = local.endpoints.lldap.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

module "authelia" {
  source    = "./modules/authelia"
  name      = local.endpoints.authelia.name
  namespace = local.endpoints.authelia.namespace
  images = {
    authelia = {
      registry   = regex(local.container_image_regex, local.container_images.authelia).repository
      repository = regex(local.container_image_regex, local.container_images.authelia).image
      tag        = regex(local.container_image_regex, local.container_images.authelia).tag
    }
    litestream = local.container_images_digest.litestream
  }
  ports = {
    metrics = local.service_ports.metrics
  }
  ldap_ca = {
    algorithm       = tls_private_key.lldap-ca.algorithm
    private_key_pem = tls_private_key.lldap-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.lldap-ca.cert_pem
  }
  ldap_endpoint = "${local.endpoints.lldap.service_fqdn}:${local.service_ports.ldaps}"
  smtp          = var.smtp
  ldap_credentials = {
    username = random_password.lldap-user.result
    password = random_password.lldap-password.result
  }
  authelia_oidc_clients = local.authelia_oidc_clients
  minio_endpoint        = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket          = "authelia"
  minio_access_secret   = local.minio_users.authelia.secret

  ingress_hostname = local.endpoints.authelia.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }

  affinity = {
    podAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = [
        {
          labelSelector = {
            matchExpressions = [
              {
                key      = "app"
                operator = "In"
                values = [
                  local.endpoints.lldap.name,
                ]
              },
            ]
          }
          topologyKey = "kubernetes.io/hostname"
          namespaces = [
            local.endpoints.lldap.namespace,
          ]
        },
      ]
    }
  }
}
