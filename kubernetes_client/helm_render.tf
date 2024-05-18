module "bootstrap" {
  source    = "./modules/bootstrap"
  name      = "bootstrap"
  namespace = "kube-system"
  release   = "0.1.1"

  node_bootstrap_user = local.kubernetes.node_bootstrap_user
  kubelet_client_user = local.kubernetes.kubelet_client_user
}

module "kube-proxy" {
  source    = "./modules/kube_proxy"
  name      = "kube-proxy"
  namespace = "kube-system"
  release   = "0.1.2"
  images = {
    kube_proxy = local.container_images.kube_proxy
  }
  ports = {
    kube_proxy     = local.host_ports.kube_proxy
    kube_apiserver = local.host_ports.apiserver
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

module "kube-dns" {
  source         = "./modules/kube_dns"
  name           = "kube-dns"
  namespace      = "kube-system"
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
          parameters  = "${local.domains.public} in-addr.arpa ip6.arpa"
          configBlock = <<-EOF
          fallthrough
          EOF
        },
        # public DNS
        {
          name        = "forward"
          parameters  = ". tls://${local.upstream_dns.ip}"
          configBlock = <<-EOF
          tls_servername ${local.upstream_dns.hostname}
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

module "fuse-device-plugin" {
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
  source    = "./modules/matchbox"
  name      = local.kubernetes_services.matchbox.name
  namespace = local.kubernetes_services.matchbox.namespace
  release   = "0.2.16"
  replicas  = 3
  images = {
    matchbox  = local.container_images.matchbox
    syncthing = local.container_images.syncthing
  }
  ports = {
    matchbox       = local.service_ports.matchbox
    matchbox_api   = local.service_ports.matchbox_api
    syncthing_peer = 22000
  }
  service_ip               = local.services.matchbox.ip
  service_hostname         = local.kubernetes_ingress_endpoints.matchbox
  ca                       = data.terraform_remote_state.sr.outputs.matchbox.ca
  cluster_service_endpoint = local.kubernetes_services.matchbox.fqdn
}

module "vaultwarden" {
  source    = "./modules/vaultwarden"
  name      = "vaultwarden"
  namespace = "vaultwarden"
  release   = "0.1.14"
  images = {
    vaultwarden = local.container_images.vaultwarden
    litestream  = local.container_images.litestream
  }
  ports = {
    vaultwarden = 8080
  }
  service_hostname = local.kubernetes_ingress_endpoints.vaultwarden
  extra_envs = {
    SENDS_ALLOWED            = false
    EMERGENCY_ACCESS_ALLOWED = false
    PASSWORD_HINTS_ALLOWED   = false
    SIGNUPS_ALLOWED          = false
    INVITATIONS_ALLOWED      = true
    DISABLE_ADMIN_TOKEN      = true
    SMTP_USERNAME            = var.smtp.username
    SMTP_FROM                = var.smtp.username
    SMTP_PASSWORD            = var.smtp.password
    SMTP_HOST                = var.smtp.host
    SMTP_PORT                = var.smtp.port
    SMTP_FROM_NAME           = "Vaultwarden"
    SMTP_SECURITY            = "starttls"
    SMTP_AUTH_MECHANISM      = "Plain"
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
  s3_db_resource            = "${data.terraform_remote_state.sr.outputs.s3.vaultwarden.resource}/db.sqlite3"
  s3_access_key_id          = data.terraform_remote_state.sr.outputs.s3.vaultwarden.access_key_id
  s3_secret_access_key      = data.terraform_remote_state.sr.outputs.s3.vaultwarden.secret_access_key
}

resource "tls_private_key" "authelia-redis-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "authelia-redis-ca" {
  private_key_pem = tls_private_key.authelia-redis-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = "redis"
    organization = "redis"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

module "authelia-redis" {
  source    = "./modules/keydb"
  name      = local.kubernetes_services.authelia_redis.name
  namespace = local.kubernetes_services.authelia_redis.namespace
  release   = "0.1.0"
  replicas  = 3
  images = {
    keydb = local.container_images.keydb
  }
  ports = {
    keydb = local.service_ports.redis
  }
  ca = {
    algorithm       = tls_private_key.authelia-redis-ca.algorithm
    private_key_pem = tls_private_key.authelia-redis-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.authelia-redis-ca.cert_pem
  }
  cluster_service_endpoint = local.kubernetes_services.authelia_redis.fqdn
}

module "authelia" {
  source         = "./modules/authelia"
  name           = local.kubernetes_services.authelia.name
  namespace      = local.kubernetes_services.authelia.namespace
  source_release = "0.8.58"
  images = {
    litestream = local.container_images.litestream
  }
  service_hostname = local.kubernetes_ingress_endpoints.auth
  lldap_ca         = data.terraform_remote_state.sr.outputs.lldap.ca
  redis_ca = {
    algorithm       = tls_private_key.authelia-redis-ca.algorithm
    private_key_pem = tls_private_key.authelia-redis-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.authelia-redis-ca.cert_pem
  }
  configmap = {
    telemetry = {
      metrics = {
        enabled = false
      }
    }
    default_redirection_url = "https://${local.kubernetes_ingress_endpoints.auth}"
    default_2fa_method      = "totp"
    theme                   = "dark"
    totp = {
      disable = false
    }
    webauthn = {
      disable = true
    }
    duo_api = {
      disable = true
    }
    authentication_backend = {
      password_reset = {
        disable    = true
        custom_url = "https://${local.kubernetes_ingress_endpoints.lldap_http}/reset-password/step1"
      }
      # https://github.com/lldap/lldap/blob/main/example_configs/authelia_config.yml
      ldap = {
        enabled        = true
        implementation = "custom"
        tls = {
          enabled         = true
          skip_verify     = false
          minimum_version = "TLS1.3"
        }
        url                    = "ldaps://${local.kubernetes_services.lldap.endpoint}:${local.service_ports.lldap}"
        base_dn                = "dc=${join(",dc=", slice(compact(split(".", local.kubernetes_ingress_endpoints.lldap_http)), 1, length(compact(split(".", local.kubernetes_ingress_endpoints.lldap_http)))))}"
        username_attribute     = "uid"
        additional_users_dn    = "ou=people"
        users_filter           = "(&({username_attribute}={input})(objectClass=person))"
        additional_groups_dn   = "ou=groups"
        groups_filter          = "(member={dn})"
        group_name_attribute   = "cn"
        mail_attribute         = "mail"
        display_name_attribute = "displayName"
        user                   = "uid=${data.terraform_remote_state.sr.outputs.lldap.user},ou=people,dc=${join(",dc=", slice(compact(split(".", local.kubernetes_ingress_endpoints.lldap_http)), 1, length(compact(split(".", local.kubernetes_ingress_endpoints.lldap_http)))))}"
      }
      file = {
        enabled = false
      }
    }
    session = {
      inactivity           = "4h"
      expiration           = "4h"
      remember_me_duration = 0
      redis = {
        enabled = true
        host    = local.kubernetes_services.authelia_redis.fqdn
        port    = local.service_ports.redis
        password = {
          disabled = true
        }
        tls = {
          enabled         = true
          skip_verify     = false
          minimum_version = "TLS1.3"
        }
      }
    }
    regulation = {
      max_retries = 4
    }
    notifier = {
      disable_startup_check = true
      smtp = {
        enabled       = true
        enabledSecret = true
        host          = var.smtp.host
        port          = var.smtp.port
        username      = var.smtp.username
        sender        = var.smtp.username
      }
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
  }
  secret = {
    jwt = {
      value = data.terraform_remote_state.sr.outputs.authelia.jwt_token
    }
    storageEncryptionKey = {
      value = data.terraform_remote_state.sr.outputs.authelia.storage_secret
    }
    session = {
      value = data.terraform_remote_state.sr.outputs.authelia.session_encryption_key
    }
    smtp = {
      value = var.smtp.password
    }
    ldap = {
      value = data.terraform_remote_state.sr.outputs.lldap.password
    }
  }
  ingress_class_name   = local.ingress_classes.ingress_nginx_external
  ingress_cert_issuer  = local.kubernetes.cert_issuer_prod
  s3_db_resource       = "${data.terraform_remote_state.sr.outputs.s3.authelia.resource}/db.sqlite3"
  s3_access_key_id     = data.terraform_remote_state.sr.outputs.s3.authelia.access_key_id
  s3_secret_access_key = data.terraform_remote_state.sr.outputs.s3.authelia.secret_access_key
}

module "lldap" {
  source    = "./modules/lldap"
  name      = local.kubernetes_services.lldap.name
  namespace = local.kubernetes_services.lldap.namespace
  release   = "0.1.0"
  images = {
    lldap      = local.container_images.lldap
    litestream = local.container_images.litestream
  }
  ports = {
    lldap       = 3890
    lldap_http  = 17170
    lldap_ldaps = local.service_ports.lldap
  }
  ca                       = data.terraform_remote_state.sr.outputs.lldap.ca
  cluster_service_endpoint = local.kubernetes_services.lldap.fqdn
  service_hostname         = local.kubernetes_ingress_endpoints.lldap_http
  storage_secret           = data.terraform_remote_state.sr.outputs.lldap.storage_secret
  extra_envs = {
    LLDAP_VERBOSE                             = true
    LLDAP_JWT_SECRET                          = data.terraform_remote_state.sr.outputs.lldap.jwt_token
    LLDAP_LDAP_USER_DN                        = data.terraform_remote_state.sr.outputs.lldap.user
    LLDAP_LDAP_USER_PASS                      = data.terraform_remote_state.sr.outputs.lldap.password
    LLDAP_SMTP_OPTIONS__ENABLE_PASSWORD_RESET = true
    LLDAP_SMTP_OPTIONS__SERVER                = var.smtp.host
    LLDAP_SMTP_OPTIONS__PORT                  = var.smtp.port
    LLDAP_SMTP_OPTIONS__SMTP_ENCRYPTION       = "STARTTLS"
    LLDAP_SMTP_OPTIONS__USER                  = var.smtp.username
    LLDAP_SMTP_OPTIONS__PASSWORD              = var.smtp.password
    LLDAP_LDAPS_OPTIONS__ENABLED              = true
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
  s3_db_resource            = "${data.terraform_remote_state.sr.outputs.s3.lldap.resource}/users.db"
  s3_access_key_id          = data.terraform_remote_state.sr.outputs.s3.lldap.access_key_id
  s3_secret_access_key      = data.terraform_remote_state.sr.outputs.s3.lldap.secret_access_key
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
    kea_peer = local.host_ports.kea_peer
    tftpd    = local.host_ports.tftpd
  }
  ipxe_boot_path  = "/ipxe.efi"
  ipxe_script_url = "http://${local.services.matchbox.ip}:${local.service_ports.matchbox}/boot.ipxe"
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
        local.domains.public,
        local.domains.kubernetes,
      ]
      mtu = lookup(network, "mtu", 1500)
      pools = [
        cidrsubnet(network.prefix, 1, 1),
      ]
    } if lookup(network, "enable_dhcp_server", false)
  ]
}

module "tailscale" {
  source  = "./modules/tailscale"
  name    = "tailscale"
  release = "0.1.1"
  images = {
    tailscale = local.container_images.tailscale
  }

  tailscale_auth_key = var.tailscale.auth_key
  tailscale_extra_envs = {
    TS_ACCEPT_DNS          = false
    TS_DEBUG_FIREWALL_MODE = "nftables"
    TS_EXTRA_ARGS = join(",", [
      "--advertise-exit-node",
    ])
    TS_ROUTES = join(",", [
      local.networks.lan.prefix,
      local.networks.service.prefix,
      local.networks.kubernetes.prefix,
    ])
  }

  aws_region             = data.terraform_remote_state.sr.outputs.ssm.tailscale.aws_region
  ssm_access_key_id      = data.terraform_remote_state.sr.outputs.ssm.tailscale.access_key_id
  ssm_secret_access_key  = data.terraform_remote_state.sr.outputs.ssm.tailscale.secret_access_key
  ssm_tailscale_resource = data.terraform_remote_state.sr.outputs.ssm.tailscale.resource
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
  user = local.users.client.name
  uid  = local.users.client.uid
  ssh_known_hosts = [
    "@cert-authority * ${data.terraform_remote_state.sr.outputs.ssh.ca.public_key_openssh}",
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
    transmission = 9091
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
  #  * TR_RPC_PORT (custom)
  cd "$TR_TORRENT_DIR"

  transmission-remote $TR_RPC_PORT \
    --torrent "$TR_TORRENT_ID" \
    --verify

  minio-client \
    -endpoint="${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}" \
    -bucket="${local.minio_buckets.downloads.name}" \
    -path="$TR_TORRENT_NAME"

  transmission-remote $TR_RPC_PORT \
    --torrent "$TR_TORRENT_ID" \
    --remove-and-delete
  EOF
  wireguard_config          = <<-EOF
  [Interface]
  Address=${var.wireguard_client.address}
  PrivateKey=${var.wireguard_client.private_key}
  PostUp=nft add table ip filter
  PostUp=nft add chain ip filter output { type filter hook output priority 0 \; }
  PostUp=nft insert rule ip filter output oifname != "%i" mark != $(wg show %i fwmark) fib daddr type != local ip daddr != ${local.networks.kubernetes_service.prefix} ip daddr != ${local.networks.kubernetes_pod.prefix} reject
  PostUp=ip route add ${local.networks.kubernetes_service.prefix} via $(ip -4 route show ${local.networks.kubernetes_pod.prefix} | awk '{print $3}')

  [Peer]
  AllowedIPs=0.0.0.0/0
  Endpoint=${var.wireguard_client.endpoint}
  PublicKey=${var.wireguard_client.public_key}
  PersistentKeepalive=25
  EOF
  service_hostname          = local.kubernetes_ingress_endpoints.transmission
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}

module "alpaca-stream" {
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
  service_ip            = local.services.alpaca_stream.ip
  alpaca_api_key_id     = var.alpaca.api_key_id
  alpaca_api_secret_key = var.alpaca.api_secret_key
  alpaca_api_base_url   = var.alpaca.api_base_url
}

# https://github.com/akrylysov/bsimp
module "bsimp" {
  source  = "./modules/bsimp"
  name    = "bsimp"
  release = "0.1.0"
  images = {
    bsimp = local.container_images.bsimp
  }
  ports = {
    bsimp = 8080
  }
  # use external endpoint here - tries to hit this in https if the service is on https (bug?)
  s3_endpoint          = "https://${local.kubernetes_ingress_endpoints.minio}"
  s3_resource          = local.minio_buckets.music.name
  s3_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  s3_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key

  service_hostname          = local.kubernetes_ingress_endpoints.bsimp
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}

module "kasm-desktop" {
  source  = "./modules/kasm_desktop"
  name    = "kasm-desktop"
  release = "0.1.1"
  images = {
    kasm = local.container_images.kasm_desktop
  }
  ports = {
    kasm     = 6901
    sunshine = 47989
  }
  user = local.users.client.name
  uid  = local.users.client.uid
  ssh_known_hosts = [
    "@cert-authority * ${data.terraform_remote_state.sr.outputs.ssh.ca.public_key_openssh}",
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
  private_key       = data.terraform_remote_state.sr.outputs.headscale.private_key
  noise_private_key = data.terraform_remote_state.sr.outputs.headscale.noise_private_key
  service_hostname  = local.kubernetes_ingress_endpoints.headscale
  extra_config = {
    grpc_allow_insecure = false
    ip_prefixes = [
      local.networks.headscale.prefix,
    ]
    derp = {
      server = {
        enabled = false
      }
      urls = [
        "https://controlplane.tailscale.com/derpmap/default",
      ]
      paths               = []
      auto_update_enabled = true
      update_frequency    = "24h"
    }
    disable_check_updates             = false
    ephemeral_node_inactivity_timeout = "30m"
    node_update_check_interval        = "10s"
    log = {
      level = "info"
    }
    acl_policy_path = ""
    dns_config = {
      override_local_dns = false
      magic_dns          = true
    }
    logtail = {
      enabled = false
    }
    randomize_client_port = false
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx_external
  nginx_ingress_annotations = local.nginx_ingress_annotations
  s3_db_resource            = "${data.terraform_remote_state.sr.outputs.s3.headscale.resource}/db.sqlite3"
  s3_access_key_id          = data.terraform_remote_state.sr.outputs.s3.headscale.access_key_id
  s3_secret_access_key      = data.terraform_remote_state.sr.outputs.s3.headscale.secret_access_key
}

module "satisfactory-server" {
  source  = "./modules/satisfactory"
  name    = "satisfactory-server"
  release = "0.1.0"
  images = {
    satisfactory_server = local.container_images.satisfactory_server
  }
  ports = {
    beacon = 15000
    game   = 7777
    query  = 15777
  }
  extra_envs = {
    AUTOSAVEINTERVAL     = 1200
    AUTOSAVEONDISCONNECT = false
    MAXTICKRATE          = 15
    CRASHREPORT          = false
    MAXPLAYERS           = 3
  }
  config_overrides = {
  }
  service_hostname = local.kubernetes_ingress_endpoints.satisfactory_server
  service_ip       = local.services.satisfactory_server.ip
  resources = {
    requests = {
      memory = "4Gi"
    }
  }
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "client"
                operator = "DoesNotExist"
              },
            ]
          },
        ]
      }
    }
  }
  volume_claim_size = "24Gi"
  storage_class     = "local-path"
}