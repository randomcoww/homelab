# DHCP

resource "random_password" "stork-agent-token" {
  length  = 32
  special = false
}

module "kea" {
  source  = "./modules/kea"
  name    = "kea"
  release = "0.1.20"
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
  ipxe_boot_file_name = "ipxe.efi"
  ipxe_script_url     = "https://${local.services.matchbox.ip}:${local.service_ports.matchbox}/boot.ipxe"
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
      pools = [
        cidrsubnet(local.networks.lan.prefix, 1, 1),
      ]
    },
    {
      prefix = local.networks.service.prefix
      mtu    = lookup(local.networks.service, "mtu", 1500)
      pools = [
        cidrsubnet(local.networks.service.prefix, 1, 1),
      ]
    },
  ]
  timezone          = local.timezone
  stork_agent_token = random_password.stork-agent-token.result
  ca_issuer_name    = local.kubernetes.cert_issuers.ca_internal
}

# PXE boot server

module "matchbox" {
  source    = "./modules/matchbox"
  name      = local.endpoints.matchbox.name
  namespace = local.endpoints.matchbox.namespace
  release   = "0.2.16"
  replicas  = 3
  images = {
    matchbox   = local.container_images.matchbox
    mountpoint = local.container_images.mountpoint
  }
  ports = {
    matchbox     = local.service_ports.matchbox
    matchbox_api = local.service_ports.matchbox_api
  }
  service_ip              = local.services.matchbox.ip
  api_service_ip          = local.services.matchbox_api.ip
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"
  ca_issuer_name          = local.kubernetes.cert_issuers.ca_internal

  minio_endpoint         = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket           = "matchbox"
  minio_access_secret    = local.minio_users.matchbox.secret
  minio_mount_extra_args = []
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
  replicas = 2
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
    bridge                       = "br-lan"
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
  service_hostname          = local.endpoints.qrcode_hostapd.ingress
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
  qrcode_value              = "WIFI:S:${random_password.hostapd-ssid.result};T:WPA;P:${random_password.hostapd-password.result};H:true;;"
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