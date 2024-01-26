module "bootstrap" {
  source    = "./modules/bootstrap"
  name      = "bootstrap"
  namespace = "kube-system"
  release   = "0.1.1"

  kube_node_bootstrap_user = local.kubernetes.node_bootstrap_user
  kube_kubelet_access_user = local.kubernetes.kubelet_access_user
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
          configBlock = <<-EOF
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
          EOF
        },
        {
          name        = "etcd"
          parameters  = "${local.domains.internal} in-addr.arpa ip6.arpa"
          configBlock = <<-EOF
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
          configBlock = <<-EOF
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

module "fuse_device_plugin" {
  source    = "./modules/fuse_device_plugin"
  name      = "fuse-device-plugin"
  namespace = "kube-system"
  release   = "0.1.1"
  images = {
    fuse_device_plugin = local.container_images.fuse_device_plugin
  }
  kubelet_root_path = local.kubernetes.kubelet_root_path
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

module "vaultwarden" {
  source  = "./modules/vaultwarden"
  name    = "vaultwarden"
  release = "0.1.14"
  images = {
    vaultwarden = local.container_images.vaultwarden
    litestream  = local.container_images.litestream
  }
  ports = {
    vaultwarden = 8080
  }
  service_hostname = local.kubernetes_ingress_endpoints.vaultwarden
  exrtra_envs = {
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
  smtp_host                 = var.smtp.host
  smtp_port                 = var.smtp.port
  smtp_username             = var.smtp.username
  smtp_password             = var.smtp.password
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
  s3_db_resource            = "${data.terraform_remote_state.sr.outputs.s3.vaultwarden.resource}/db.sqlite3"
  s3_access_key_id          = data.terraform_remote_state.sr.outputs.s3.vaultwarden.access_key_id
  s3_secret_access_key      = data.terraform_remote_state.sr.outputs.s3.vaultwarden.secret_access_key
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
  ingress_class_name     = local.ingress_classes.ingress_nginx_external
  ingress_cert_issuer    = local.kubernetes.cert_issuer_prod
  s3_db_resource         = "${data.terraform_remote_state.sr.outputs.s3.authelia.resource}/db.sqlite3"
  s3_access_key_id       = data.terraform_remote_state.sr.outputs.s3.authelia.access_key_id
  s3_secret_access_key   = data.terraform_remote_state.sr.outputs.s3.authelia.secret_access_key
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

module "code" {
  source  = "./modules/code_server"
  name    = "code"
  release = "0.1.1"
  images = {
    code_server = local.container_images.code_server
    tailscale   = local.container_images.tailscale
    syncthing   = local.container_images.syncthing
  }
  sync_replicas = 1
  ports = {
    code_server    = 8080
    syncthing_peer = 22000
  }
  user = "code"
  uid  = 10000
  ssh_known_hosts = [
    "@cert-authority * ${data.terraform_remote_state.sr.outputs.ssh_ca.public_key_openssh}",
  ]
  code_server_resources = {
    limits = {
      "github.com/fuse" = 1
      "nvidia.com/gpu"  = 1
    }
  }

  tailscale_auth_key = var.tailscale.auth_key
  tailscale_extra_envs = {
    TS_ACCEPT_DNS          = true
    TS_DEBUG_FIREWALL_MODE = "nftables"
    TS_EXTRA_ARGS = join(",", [
      "--advertise-exit-node",
    ])
    TS_ROUTES = join(",", [
      local.networks.lan.prefix,
      local.networks.service.prefix,
      local.networks.kubernetes.prefix,
      local.networks.kubernetes_service.prefix,
      local.networks.kubernetes_pod.prefix,
    ])
  }

  aws_region             = data.terraform_remote_state.sr.outputs.ssm.tailscale.aws_region
  ssm_access_key_id      = data.terraform_remote_state.sr.outputs.ssm.tailscale.access_key_id
  ssm_secret_access_key  = data.terraform_remote_state.sr.outputs.ssm.tailscale.secret_access_key
  ssm_tailscale_resource = data.terraform_remote_state.sr.outputs.ssm.tailscale.resource

  service_hostname          = local.kubernetes_ingress_endpoints.code_server
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
  volume_claim_size         = "128Gi"
  storage_class             = "local-path"
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
    blocklist-enabled            = true
    blocklist-url                = "http://list.iblocklist.com/?list=ydxerpxkpcfqjaybcssw&fileformat=p2p&archiveformat=gz"
    download-queue-enabled       = true
    encryption                   = 2
    max-peers-global             = 1000
    port-forwarding-enabled      = false
    preallocation                = 0
    queue-stalled-enabled        = true
    ratio-limit                  = 0
    ratio-limit-enabled          = true
    rename-partial-files         = true
    rpc-authentication-required  = false
    rpc-host-whitelist-enabled   = false
    rpc-url                      = "/transmission/"
    rpc-whitelist-enabled        = false
    script-torrent-done-enabled  = true
    speed-limit-down-enabled     = false
    speed-limit-up-enabled       = true
    start-added-torrents         = true
    trash-original-torrent-files = true
  }
  torrent_done_script       = <<-EOF
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
    -path="$TR_TORRENT_NAME"

  transmission-remote 127.0.0.1:${local.service_ports.transmission} \
    --torrent "$TR_TORRENT_ID" \
    --remove-and-delete
  EOF
  wireguard_config          = <<-EOF
  [Interface]
  Address=${var.wireguard_client.address}
  PrivateKey=${var.wireguard_client.private_key}
  PostUp=nft add table ip filter && nft add chain ip filter output { type filter hook output priority 0 \; } && nft insert rule ip filter output oifname != "%i" mark != $(wg show %i fwmark) fib daddr type != local ip daddr != ${local.networks.kubernetes_service.prefix} ip daddr != ${local.networks.kubernetes_pod.prefix} reject && ip route add ${local.networks.kubernetes_service.prefix} via $(ip route | grep default | awk '{print $3}')

  [Peer]
  AllowedIPs=0.0.0.0/0
  Endpoint=${var.wireguard_client.endpoint}
  PublicKey=${var.wireguard_client.public_key}
  PersistentKeepalive=25
  EOF
  service_hostname          = local.kubernetes_ingress_endpoints.transmission
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
  volume_claim_size         = "32Gi"
  storage_class             = "local-path"
}

module "alpaca_stream" {
  source  = "./modules/alpaca_stream"
  name    = "alpaca-stream"
  release = "0.1.1"
  images = {
    alpaca_stream = local.container_images.alpaca_stream
  }
  ports = {
    alpaca_stream = local.service_ports.alpaca_stream
  }
  service_hostname      = local.kubernetes_ingress_endpoints.alpaca_stream
  alpaca_api_key_id     = var.alpaca.api_key_id
  alpaca_api_secret_key = var.alpaca.api_secret_key
  alpaca_api_base_url   = var.alpaca.api_base_url
}

module "mpd" {
  source  = "./modules/mpd_s3"
  name    = "mpd"
  release = "0.2.2"
  images = {
    mpd   = local.container_images.mpd
    mympd = local.container_images.mympd
  }
  ports = {
    mympd             = 8080
    rclone            = 8081
    audio_output_base = 8082
  }
  audio_outputs = [
    {
      name = "flac-3"
      config = {
        tags        = "yes"
        format      = "48000:24:2"
        always_on   = "yes"
        encoder     = "flac"
        compression = 3
        max_clients = 2
      }
    },
    {
      name = "lame-9"
      config = {
        tags        = "yes"
        format      = "48000:24:2"
        always_on   = "yes"
        encoder     = "lame"
        quality     = 9
        max_clients = 2
      }
    },
  ]
  s3_endpoint       = "http://${local.kubernetes_service_endpoints.minio}:${local.service_ports.minio}"
  s3_music_resource = local.minio_buckets.music.name
  s3_cache_resource = local.minio_buckets.mpd.name
  resources = {
    limits = {
      "github.com/fuse" = 1
    }
  }

  service_hostname          = local.kubernetes_ingress_endpoints.mpd
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}

module "kasm_desktop" {
  source  = "./modules/kasm_desktop"
  name    = "kasm-desktop"
  release = "0.1.1"
  images = {
    kasm_desktop = local.container_images.kasm_desktop
  }
  user = "kasm-user"
  uid  = 10000
  ssh_known_hosts = [
    "@cert-authority * ${data.terraform_remote_state.sr.outputs.ssh_ca.public_key_openssh}",
  ]
  extra_envs = {
    VK_ICD_FILENAMES = join(":", [
      "/usr/share/vulkan/icd.d/radeon_icd.i686.json",
      "/usr/share/vulkan/icd.d/radeon_icd.x86_64.json",
    ])
    AMD_VULKAN_ICD = "RADV"
    RESOLUTION     = "2560x1600"
  }
  resources = {
    limits = {
      "github.com/fuse" = 1
      "amd.com/gpu"     = 1
    }
  }

  sunshine_service_hostname = local.kubernetes_ingress_endpoints.sunshine
  sunshine_service_ip       = local.services.sunshine.ip

  kasm_service_hostname     = local.kubernetes_ingress_endpoints.kasm
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
  volume_claim_size         = "128Gi"
  storage_class             = "local-path"
}

# Not working with cloudflare tunnel
# https://github.com/cloudflare/cloudflared/issues/990
module "headscale" {
  source  = "./modules/headscale"
  name    = "headscale"
  release = "0.1.0"
  images = {
    headscale  = local.container_images.headscale
    litestream = local.container_images.litestream
  }
  ports = {
    headscale      = 8080
    headscale_grpc = 50443
  }
  network_prefix            = local.networks.headscale.prefix
  private_key               = data.terraform_remote_state.sr.outputs.headscale.private_key
  noise_private_key         = data.terraform_remote_state.sr.outputs.headscale.noise_private_key
  service_hostname          = local.kubernetes_ingress_endpoints.headscale
  ingress_class_name        = local.ingress_classes.ingress_nginx_external
  nginx_ingress_annotations = local.nginx_ingress_annotations
  s3_db_resource            = "${data.terraform_remote_state.sr.outputs.s3.headscale.resource}/db.sqlite3"
  s3_access_key_id          = data.terraform_remote_state.sr.outputs.s3.headscale.access_key_id
  s3_secret_access_key      = data.terraform_remote_state.sr.outputs.s3.headscale.secret_access_key
}