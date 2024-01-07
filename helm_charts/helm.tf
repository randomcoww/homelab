locals {
  cert_issuer_prod    = "letsencrypt-prod"
  cert_issuer_staging = "letsencrypt-staging"
}

module "hostapd" {
  source   = "./modules/hostapd"
  name     = "hostapd"
  release  = "0.1.8"
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
                key      = "hostapd"
                operator = "Exists"
              },
            ]
          },
        ]
      }
    }
  }
  config = merge({
    # sae_password=
    # ssid=
    # country_code=
    # # one of: 36 44 52 60 100 108 116 124 132 140 149 157 184 192
    # channel=
    # # one of: 42 58 106 122 138 155
    vht_oper_centr_freq_seg0_idx = var.hostapd.channel + 6
    interface                    = "wlan0"
    bridge                       = "br-lan"
    driver                       = "nl80211"
    noscan                       = 1
    preamble                     = 1
    wpa                          = 2
    wpa_key_mgmt                 = "SAE"
    wpa_pairwise                 = "CCMP"
    group_cipher                 = "CCMP"
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
  }, var.hostapd)
}

resource "local_file" "hostapd" {
  for_each = module.hostapd.manifests
  content  = each.value
  filename = "${path.module}/output/charts/${each.key}"
}

module "kea" {
  source  = "./modules/kea"
  name    = "kea"
  release = "0.1.18"
  images = {
    kea   = local.container_images.kea
    tftpd = local.container_images.tftpd
  }
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "kea"
                operator = "Exists"
              },
            ]
          },
        ]
      }
    }
  }
  service_ips = [
    local.services.cluster_kea_primary.ip,
    local.services.cluster_kea_secondary.ip,
  ]
  ports = {
    kea_peer = local.ports.kea_peer
    tftpd    = local.ports.tftpd
  }
  ipxe_boot_path  = "/ipxe.efi"
  ipxe_script_url = "http://${local.services.matchbox.ip}:${local.ports.matchbox}/boot.ipxe"
  networks = [
    for _, network in local.networks :
    {
      prefix = network.prefix
      routers = [
        local.services.gateway.ip,
      ]
      domain_name_servers = [
        local.services.external_dns.ip,
      ]
      domain_search = [
        local.domains.internal,
      ]
      mtu = network.mtu
      pools = [
        cidrsubnet(network.prefix, 1, 1),
      ]
    } if lookup(network, "enable_dhcp_server", false)
  ]
}

resource "local_file" "kea" {
  for_each = module.kea.manifests
  content  = each.value
  filename = "${path.module}/output/charts/${each.key}"
}

module "matchbox" {
  source   = "./modules/matchbox"
  name     = "matchbox"
  release  = "0.2.16"
  replicas = 3
  images = {
    matchbox  = local.container_images.matchbox
    syncthing = local.container_images.syncthing
  }
  ports = {
    matchbox       = local.ports.matchbox
    matchbox_api   = local.ports.matchbox_api
    syncthing_peer = 22000
  }
  service_ip       = local.services.matchbox.ip
  service_hostname = local.kubernetes_ingress_endpoints.matchbox
  ca               = data.terraform_remote_state.sr.outputs.matchbox_ca
}

resource "local_file" "matchbox" {
  for_each = module.matchbox.manifests
  content  = each.value
  filename = "${path.module}/output/charts/${each.key}"
}

module "vaultwarden" {
  source  = "./modules/vaultwarden"
  name    = "vaultwarden"
  release = "0.1.14"
  images = {
    vaultwarden = local.container_images.vaultwarden
    litestream  = local.container_images.litestream
  }
  ports = {
    vaultwarden = local.service_ports.vaultwarden
  }
  service_hostname = local.kubernetes_ingress_endpoints.vaultwarden
  additional_envs = {
    SENDS_ALLOWED            = false
    EMERGENCY_ACCESS_ALLOWED = false
    PASSWORD_HINTS_ALLOWED   = false
    SIGNUPS_ALLOWED          = false
    INVITATIONS_ALLOWED      = true
    DISABLE_ADMIN_TOKEN      = true
    SMTP_FROM_NAME           = "Vaultwarden"
    SMTP_SECURITY            = "starttls"
    SMTP_AUTH_MECHANISM      = "Plain"
  }
  smtp_host            = var.smtp.host
  smtp_port            = var.smtp.port
  smtp_username        = var.smtp.username
  smtp_password        = var.smtp.password
  ingress_class_name   = local.ingress_classes.ingress_nginx
  ingress_cert_issuer  = local.cert_issuer_prod
  ingress_auth_url     = "http://${local.kubernetes_service_endpoints.authelia}/api/verify"
  ingress_auth_signin  = "https://${local.kubernetes_ingress_endpoints.auth}?rm=$request_method"
  s3_db_resource       = "${data.terraform_remote_state.sr.outputs.s3.vaultwarden.resource}/db.sqlite3"
  s3_access_key_id     = data.terraform_remote_state.sr.outputs.s3.vaultwarden.access_key_id
  s3_secret_access_key = data.terraform_remote_state.sr.outputs.s3.vaultwarden.secret_access_key
}

resource "local_file" "vaultwarden" {
  for_each = module.vaultwarden.manifests
  content  = each.value
  filename = "${path.module}/output/charts/${each.key}"
}

module "authelia" {
  source         = "./modules/authelia"
  name           = split(".", local.kubernetes_service_endpoints.authelia)[0]
  namespace      = split(".", local.kubernetes_service_endpoints.authelia)[1]
  release        = "0.1.1"
  source_release = "0.8.58"
  images = {
    litestream = local.container_images.litestream
  }
  users = {
    for email, user in var.authelia_users :
    email => merge({
      email       = email
      displayname = email
    }, user)
  }
  access_control = {
    default_policy = "two_factor"
    rules = [
      {
        domain    = local.kubernetes_ingress_endpoints.vaultwarden
        resources = ["^/admin.*"]
        policy    = "two_factor"
      },
      {
        domain = local.kubernetes_ingress_endpoints.vaultwarden
        policy = "bypass"
      },
    ]
  }
  service_hostname       = local.kubernetes_ingress_endpoints.auth
  jwt_token              = data.terraform_remote_state.sr.outputs.authelia.jwt_token
  storage_secret         = data.terraform_remote_state.sr.outputs.authelia.storage_secret
  session_encryption_key = data.terraform_remote_state.sr.outputs.authelia.session_encryption_key
  smtp_host              = var.smtp.host
  smtp_port              = var.smtp.port
  smtp_username          = var.smtp.username
  smtp_password          = var.smtp.password
  ingress_class_name     = local.ingress_classes.ingress_nginx
  ingress_cert_issuer    = local.cert_issuer_prod
  s3_db_resource         = "${data.terraform_remote_state.sr.outputs.s3.authelia.resource}/db.sqlite3"
  s3_access_key_id       = data.terraform_remote_state.sr.outputs.s3.authelia.access_key_id
  s3_secret_access_key   = data.terraform_remote_state.sr.outputs.s3.authelia.secret_access_key
}

resource "local_file" "authelia" {
  for_each = module.authelia.manifests
  content  = each.value
  filename = "${path.module}/output/charts/${each.key}"
}