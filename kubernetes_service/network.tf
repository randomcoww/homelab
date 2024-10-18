
# DHCP

module "kea" {
  source  = "./modules/kea"
  name    = "kea"
  release = "0.1.20"
  images = {
    kea   = local.container_images.kea
    tftpd = local.container_images.tftpd
  }
  service_ips = [
    local.services.cluster_kea_primary.ip,
    local.services.cluster_kea_secondary.ip,
  ]
  ports = {
    kea_peer = local.host_ports.kea_peer
    tftpd    = local.host_ports.tftpd
  }
  ipxe_boot_path  = "/ipxe.efi"
  ipxe_script_url = "http://${local.services.matchbox.ip}:${local.service_ports.matchbox}/boot.ipxe"
  networks = [
    {
      prefix = local.networks.node.prefix
      routers = [
        local.services.gateway.ip,
      ]
      domain_name_servers = [
        local.services.external_dns.ip,
      ]
      domain_search = [
        local.domains.public,
        local.domains.kubernetes,
      ]
      mtu = lookup(local.networks.node, "mtu", 1500)
      pools = [
        cidrsubnet(local.networks.node.prefix, 1, 1),
      ]
    },
  ]
  timezone = local.timezone
}

# Kube-vip

module "kube-vip" {
  source    = "./modules/kube_vip"
  name      = "kube-vip"
  namespace = "kube-system"
  release   = "0.1.0"
  images = {
    kube_vip = local.container_images.kube_vip
  }
  ports = {
    apiserver = local.host_ports.apiserver,
  }
  bgp_as     = local.ha.bgp_service_as
  bgp_peeras = local.ha.bgp_node_as
  bgp_neighbor_ips = [
    for _, host in local.members.bgp_export :
    cidrhost(local.networks.service.prefix, host.netnum)
  ]
  apiserver_ip = local.services.apiserver.ip
}

# PXE boot server

module "matchbox" {
  source                   = "./modules/matchbox"
  cluster_service_endpoint = local.kubernetes_services.matchbox.fqdn
  release                  = "0.2.16"
  replicas                 = 3
  images = {
    matchbox  = local.container_images.matchbox
    syncthing = local.container_images.syncthing
  }
  ports = {
    matchbox     = local.service_ports.matchbox
    matchbox_api = local.service_ports.matchbox_api
  }
  service_ip     = local.services.matchbox.ip
  api_service_ip = local.services.matchbox_api.ip
  ca             = data.terraform_remote_state.sr.outputs.matchbox.ca
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
  release  = "0.1.8"
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
                key      = "hostapd"
                operator = "Exists"
              },
            ]
          },
        ]
      }
    }
  }
  # https://w1.fi/cgit/hostap/plain/hostapd/hostapd.conf
  config = {
    country_code                 = "US"
    channel                      = 149 # one of 36 44 52 60 100 108 116 124 132 140 149 157 184 192
    vht_oper_centr_freq_seg0_idx = 155 # channel+6 and one of 42 58 106 122 138 155
    ssid                         = random_password.hostapd-ssid.result
    sae_password                 = random_password.hostapd-password.result
    interface                    = "wlan0"
    bridge                       = "br-lan"
    driver                       = "nl80211"
    noscan                       = 1
    preamble                     = 1
    wpa                          = 2
    wpa_key_mgmt                 = "SAE"
    wpa_pairwise                 = "CCMP"
    hw_mode                      = "a"
    require_ht                   = 1
    require_vht                  = 1
    ieee80211n                   = 1
    ieee80211ax                  = 1
    ieee80211d                   = 1
    ieee80211h                   = 0
    ieee80211w                   = 2
    vht_oper_chwidth             = 1
    ignore_broadcast_ssid        = 0
    auth_algs                    = 1
    wmm_enabled                  = 1
    disassoc_low_ack             = 0
    ap_max_inactivity            = 900
    ht_capab = "[${join("][", [
      "HT40-", "HT40+", "SHORT-GI-20", "SHORT-GI-40",
      "LDPC", "TX-STBC", "RX-STBC1", "MAX-AMSDU-7935",
    ])}]"
    vht_capab = "[${join("][", [
      "RXLDPC", "TX-STBC-2BY1", "RX-STBC-1", "SHORT-GI-80",
      "MAX-MPDU-11454", "MAX-A-MPDU-LEN-EXP3",
      "BF-ANTENNA-1", "SOUNDING-DIMENSION-1", "SU-BEAMFORMEE",
      "BF-ANTENNA-2", "SOUNDING-DIMENSION-2", "MU-BEAMFORMEE",
      "RX-ANTENNA-PATTERN", "TX-ANTENNA-PATTERN",
    ])}]"
  }
}

# Render QR code for wifi

module "qrcode" {
  source   = "./modules/qrcode"
  name     = "qrcode"
  replicas = 2
  release  = "0.1.0"
  images = {
    qrcode = local.container_images.qrcode_generator
  }
  service_hostname          = local.kubernetes_ingress_endpoints.qrcode
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
  qrcodes = {
    wifi = {
      service_hostname = local.kubernetes_ingress_endpoints.qrcode_wifi
      code             = "WIFI:S:${random_password.hostapd-ssid.result};T:WPA;P:${random_password.hostapd-password.result};H:true;;"
    }
  }
}

# Tailscale remote access

module "tailscale" {
  source    = "./modules/tailscale"
  name      = "tailscale"
  namespace = "tailscale"
  release   = "0.1.1"
  images = {
    tailscale = local.container_images.tailscale
  }

  tailscale_auth_key = data.terraform_remote_state.sr.outputs.tailscale_auth_key
  tailscale_extra_envs = [
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
        local.networks[local.services.gateway.network.name].prefix,
        local.networks[local.services.apiserver.network.name].prefix,
        local.networks.service.prefix,
      ]))
    },
  ]
}