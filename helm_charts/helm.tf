locals {
  cert_issuer_prod    = "letsencrypt-prod"
  cert_issuer_staging = "letsencrypt-staging"
}

module "bootstrap" {
  source    = "./modules/bootstrap"
  name      = "bootstrap"
  namespace = "kube-system"
  release   = "0.1.1"
}

module "kube_proxy" {
  source    = "./modules/kube_proxy"
  name      = "kube-proxy"
  namespace = "kube-system"
  release   = "0.1.2"
  images = {
    kube_proxy = local.container_images.kube_proxy
  }
  ports = {
    kube_proxy     = local.ports.kube_proxy
    kube_apiserver = local.ports.apiserver
  }
  kubernetes_pod_prefix = local.networks.kubernetes_pod.prefix
  kube_apiserver_ip     = local.services.apiserver.ip
}

module "flannel" {
  source    = "./modules/flannel"
  name      = "flannel"
  namespace = "kube-system"
  release   = "0.1.2"
  images = {
    flannel            = local.container_images.flannel
    flannel_cni_plugin = local.container_images.flannel_cni_plugin
  }
  kubernetes_pod_prefix     = local.networks.kubernetes_pod.prefix
  cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
  cni_version               = "0.3.1"
}

module "kapprover" {
  source    = "./modules/kapprover"
  name      = "kapprover"
  namespace = "kube-system"
  release   = "0.1.1"
  replicas  = 2
  images = {
    kapprover = local.container_images.kapprover
  }
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

module "kea" {
  source  = "./modules/kea"
  name    = "kea"
  release = "0.1.20"
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

module "kube_dns" {
  source         = "./modules/kube_dns"
  name           = "kube-dns"
  namespace      = "kube-system"
  release        = "0.1.4"
  source_release = "1.29.0"
  replicas       = 3
  images = {
    etcd         = local.container_images.etcd
    external_dns = local.container_images.external_dns
  }
  service_cluster_ip = local.services.cluster_dns.ip
  service_ip         = local.services.external_dns.ip
  servers = [
    {
      zones = [
        {
          zone = "."
        },
      ]
      port = 53
      plugins = [
        {
          name = "health"
        },
        {
          name = "ready"
        },
        {
          name        = "kubernetes"
          parameters  = "${local.domains.kubernetes} in-addr.arpa ip6.arpa"
          configBlock = <<EOF
pods insecure
fallthrough in-addr.arpa ip6.arpa
EOF
        },
        {
          name        = "etcd"
          parameters  = "${local.domains.internal} in-addr.arpa ip6.arpa"
          configBlock = <<EOF
fallthrough
EOF
        },
        # mDNS
        {
          name       = "forward"
          parameters = "${local.domains.internal_mdns} dns://${local.services.gateway.ip}:${local.ports.gateway_dns}"
        },
        # public DNS
        {
          name        = "forward"
          parameters  = ". tls://${local.upstream_dns.ip}"
          configBlock = <<EOF
tls_servername ${local.upstream_dns.tls_servername}
health_check 5s
EOF
        },
        {
          name       = "cache"
          parameters = 30
        },
      ]
    },
  ]
}

module "transmission" {
  source  = "./modules/transmission"
  name    = "transmission"
  release = "0.1.6"
  images = {
    transmission = local.container_images.transmission
    wireguard    = local.container_images.wireguard
  }
  ports = {
    transmission = local.service_ports.transmission
  }
  transmission_settings = {
    blocklist-enabled           = true
    blocklist-url               = "http://list.iblocklist.com/?list=ydxerpxkpcfqjaybcssw&fileformat=p2p&archiveformat=gz"
    incomplete-dir-enabled      = true
    download-queue-enabled      = true
    download-queue-size         = 20
    encryption                  = 2
    max-peers-global            = 1000
    message-level               = 2
    peer-limit-global           = 1000
    peer-limit-per-torrent      = 1000
    port-forwarding-enabled     = false
    preallocation               = 0
    queue-stalled-enabled       = true
    queue-stalled-minutes       = 5
    ratio-limit                 = 0
    ratio-limit-enabled         = true
    rename-partial-files        = true
    rpc-authentication-required = false
    rpc-host-whitelist-enabled  = false
    rpc-url                     = "/transmission/"
    rpc-whitelist-enabled       = false
    script-torrent-done-enabled = true
    speed-limit-down-enabled    = false
    speed-limit-up              = 10
    speed-limit-up-enabled      = true
    start-added-torrents        = true
  }
  torrent_done_script = <<EOF
#!/bin/sh
set -xe
#  * TR_APP_VERSION
#  * TR_TIME_LOCALTIME
#  * TR_TORRENT_DIR
#  * TR_TORRENT_HASH
#  * TR_TORRENT_ID
#  * TR_TORRENT_NAME
cd "$TR_TORRENT_DIR"

transmission-remote 127.0.0.1:${local.service_ports.transmission} \
  --torrent "$TR_TORRENT_ID" \
  --verify

minio-client \
  -endpoint="${local.kubernetes_service_endpoints.minio}:${local.service_ports.minio}" \
  -bucket="${local.minio_buckets.downloads.name}" \
  -access-key-id="${data.terraform_remote_state.sr.outputs.minio.access_key_id}" \
  -secret-access-key="${data.terraform_remote_state.sr.outputs.minio.secret_access_key}" \
  -path="$TR_TORRENT_NAME"

transmission-remote 127.0.0.1:${local.service_ports.transmission} \
  --torrent "$TR_TORRENT_ID" \
  --remove-and-delete
EOF
  wireguard_config    = <<EOF
[Interface]
Address=${var.wireguard_client.address}
PrivateKey=${var.wireguard_client.private_key}
PostUp=nft add table ip filter && nft add chain ip filter output { type filter hook output priority 0 \; } && nft insert rule ip filter output oifname != "%i" mark != $(wg show %i fwmark) fib daddr type != local ip daddr != ${local.networks.kubernetes_service.prefix} ip daddr != ${local.networks.kubernetes_pod.prefix} reject && ip route add ${local.networks.kubernetes_service.prefix} via $(ip route | grep default | awk '{print $3}')

[Peer]
AllowedIPs=0.0.0.0/0,::0/0
Endpoint=${var.wireguard_client.endpoint}
PublicKey=${var.wireguard_client.public_key}
PersistentKeepalive=25
EOF
  service_hostname    = local.kubernetes_ingress_endpoints.transmission
  ingress_class_name  = local.ingress_classes.ingress_nginx
  ingress_cert_issuer = local.cert_issuer_prod
  ingress_auth_url    = "http://${local.kubernetes_service_endpoints.authelia}/api/verify"
  ingress_auth_signin = "https://${local.kubernetes_ingress_endpoints.auth}?rm=$request_method"
  volume_claim_size   = "32Gi"
  storage_class       = "local-path"
}

resource "local_file" "manifests" {
  for_each = merge(
    module.bootstrap.manifests,
    module.kube_proxy.manifests,
    module.flannel.manifests,
    module.kapprover.manifests,
    module.hostapd.manifests,
    module.kea.manifests,
    module.vaultwarden.manifests,
    module.authelia.manifests,
    module.kube_dns.manifests,
    module.transmission.manifests,
  )
  content  = each.value
  filename = "${path.module}/output/charts/${each.key}"
}