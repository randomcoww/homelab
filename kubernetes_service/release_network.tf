# DHCP

module "kea" {
  source    = "./modules/kea"
  name      = local.endpoints.kea.name
  namespace = local.endpoints.kea.namespace
  release   = "0.1.20"
  images = {
    kea         = local.container_images.kea
    ipxe        = local.container_images.ipxe
    stork_agent = local.container_images.stork_agent
  }
  service_ips = [
    local.services.cluster_kea_primary.ip,
    local.services.cluster_kea_secondary.ip,
  ]
  ports = {
    kea_peer       = local.host_ports.kea_peer
    kea_metrics    = local.host_ports.kea_metrics
    kea_ctrl_agent = local.host_ports.kea_ctrl_agent
    ipxe           = local.host_ports.ipxe
    ipxe_tftp      = local.host_ports.ipxe_tftp
  }
  ipxe_boot_file_name  = "ipxe.efi"
  ipxe_script_base_url = "https://${local.services.minio.ip}:${local.service_ports.minio}/boot/ipxe-"
  networks = [
    {
      prefix = local.networks.lan.prefix
      routers = [
        local.services.gateway.ip,
      ]
      domain_name_servers = [
        local.services.external_dns.ip,
      ]
      domain_search = [
        local.domains.kubernetes,
        local.domains.public,
      ]
      mtu = 1500 # Force LAN clients to 1500
    },
    {
      prefix = local.networks.service.prefix
      mtu    = lookup(local.networks.service, "mtu", 1500)
    },
  ]
  timezone       = local.timezone
  ca_issuer_name = local.kubernetes.cert_issuers.ca_internal
}

# Wifi AP

resource "random_password" "hostapd-ssid" {
  length  = 8
  special = false
}

resource "random_password" "hostapd-password" {
  length  = 32
  special = false
}

module "hostapd" {
  source   = "./modules/hostapd"
  name     = "hostapd"
  release  = "0.1.0"
  replicas = 1
  images = {
    hostapd = local.container_images.hostapd
  }
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "feature.node.kubernetes.io/hostapd-compat"
                operator = "In"
                values = [
                  "true",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  # https://w1.fi/cgit/hostap/plain/hostapd/hostapd.conf
  # https://blog.fraggod.net/2017/04/27/wifi-hostapd-configuration-for-80211ac-networks.html
  config = {
    country_code                 = "PA"
    channel                      = 132 # one of 36 44 52 60 100 108 116 124 132 140 149 157 184 192
    vht_oper_centr_freq_seg0_idx = 138 # channel+6 and one of 42 58 106 122 138 155
    vht_oper_chwidth             = 1
    ssid                         = random_password.hostapd-ssid.result
    sae_password                 = random_password.hostapd-password.result
    interface                    = "wlan0"
    bridge                       = "br0"
    driver                       = "nl80211"
    noscan                       = 1
    wpa                          = 2
    wpa_key_mgmt                 = "SAE"
    wpa_pairwise                 = "CCMP"
    hw_mode                      = "a"
    ieee80211n                   = 1
    ieee80211ac                  = 1
    ieee80211d                   = 1
    ieee80211w                   = 2
    auth_algs                    = 1
    wmm_enabled                  = 1
    require_ht                   = 1
    require_vht                  = 1
    skip_inactivity_poll         = 1
    ht_capab = "[${join("][", [
      "HT40-", "HT40+", "SHORT-GI-20", "SHORT-GI-40",
      "LDPC", "TX-STBC", "RX-STBC1", "MAX-AMSDU-7935",
    ])}]"
    vht_capab = "[${join("][", [
      "RXLDPC", "TX-STBC-2BY1", "RX-STBC-1", "SHORT-GI-80", "SHORT-GI-160",
      "MAX-MPDU-11454", "MAX-A-MPDU-LEN-EXP2",
      "BF-ANTENNA-1", "SOUNDING-DIMENSION-1", "SU-BEAMFORMEE",
      "BF-ANTENNA-2", "SOUNDING-DIMENSION-2", "MU-BEAMFORMEE",
    ])}]"
  }
  resources = {
    limits = {
      "squat.ai/rfkill" = 1
    }
  }
}

# Render QR code for wifi

module "qrcode-hostapd" {
  source    = "./modules/qrcode"
  name      = local.endpoints.qrcode_hostapd.name
  namespace = local.endpoints.qrcode_hostapd.namespace
  replicas  = 2
  release   = "0.1.0"
  images = {
    qrcode = local.container_images.qrcode_generator
  }
  service_hostname   = local.endpoints.qrcode_hostapd.ingress
  ingress_class_name = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })
  qrcode_value = "WIFI:S:${random_password.hostapd-ssid.result};T:WPA;P:${random_password.hostapd-password.result};H:true;;"
}

# Tailscale remote access

module "tailscale" {
  source    = "./modules/tailscale"
  name      = "tailscale"
  namespace = "tailscale"
  release   = "0.1.0"
  replicas  = 2
  images = {
    tailscale = local.container_images.tailscale
  }
  tailscale_auth_key = data.terraform_remote_state.sr.outputs.tailscale_auth_key
  extra_envs = [
    {
      name  = "TS_ACCEPT_DNS"
      value = false
    },
    {
      name  = "TS_DEBUG_FIREWALL_MODE"
      value = "nftables"
    },
    {
      name = "TS_EXTRA_ARGS"
      value = join(",", [
        "--advertise-exit-node",
      ])
    },
    {
      name = "TS_ROUTES"
      value = join(",", distinct([
        local.networks[local.services.apiserver.network.name].prefix,
        local.networks.service.prefix,
      ]))
    },
  ]
}

# Cloudflare tunnel
/*
resource "helm_release" "cloudflare-tunnel" {
  name          = "cloudflare-tunnel"
  namespace     = "default"
  repository    = "https://cloudflare.github.io/helm-charts/"
  chart         = "cloudflare-tunnel"
  wait          = false
  wait_for_jobs = false
  version       = "0.3.2"
  max_history   = 2
  timeout       = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      cloudflare = {
        account    = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.account_id
        tunnelName = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.name
        tunnelId   = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.id
        secret     = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.tunnel_secret
        ingress = [
          {
            hostname = "*.${local.domains.public}"
            service  = "https://${local.endpoints.ingress_nginx.service}"
          },
        ]
      }
    }),
  ]
}
*/