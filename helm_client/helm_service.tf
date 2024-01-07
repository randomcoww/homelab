# mpd #

resource "helm_release" "mpd" {
  name       = "mpd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "mpd"
  wait       = false
  version    = "0.4.6"
  values = [
    yamlencode({
      config = {
        filesystem_charset = "UTF-8"
        auto_update        = "yes"
        metadata_to_use    = "AlbumArtist,Artist,Album,Title,Track,Disc,Genre,Name"
      }
      audioOutputs = [
        {
          name = "flac-3"
          port = 8180
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
          port = 8181
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
      minioEndPoint = "http://${local.kubernetes_service_endpoints.minio}:${local.service_ports.minio}"
      minioBucket   = local.minio_buckets.music.name
      persistence = {
        accessMode   = "ReadWriteOnce"
        storageClass = "local-path"
        size         = "1Gi"
      }
      images = {
        mpd    = local.container_images.mpd
        mympd  = local.container_images.mympd
        rclone = local.container_images.rclone
      }
      ingress = {
        enabled          = true
        ingressClassName = local.ingress_classes.ingress_nginx
        annotations      = local.nginx_ingress_annotations
        tls = [
          local.tls_wildcard,
        ]
        hosts = [
          local.kubernetes_ingress_endpoints.mpd,
        ]
      }
      uiIngress = {
        enabled          = true
        ingressClassName = local.ingress_classes.ingress_nginx
        path             = "/"
        annotations      = local.nginx_ingress_annotations
        tls = [
          local.tls_wildcard,
        ]
        hosts = [
          local.kubernetes_ingress_endpoints.mpd,
        ]
      }
    }),
  ]
}

# transmission with minio storage #

resource "helm_release" "transmission" {
  name       = "transmission"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "transmission"
  wait       = false
  version    = "0.1.8"
  values = [
    yamlencode({
      images = {
        transmission = local.container_images.transmission
        wireguard    = local.container_images.wireguard
      }
      ports = {
        transmission = local.service_ports.transmission
      }
      persistence = {
        accessMode   = "ReadWriteOnce"
        storageClass = "local-path"
        size         = "32Gi"
      }
      service = {
        type = "ClusterIP"
        port = local.service_ports.transmission
      }
      ingress = {
        enabled          = true
        ingressClassName = local.ingress_classes.ingress_nginx
        path             = "/"
        annotations      = local.nginx_ingress_annotations
        tls = [
          local.tls_wildcard,
        ]
        hosts = [
          local.kubernetes_ingress_endpoints.transmission,
        ]
      }
      transmission = {
        homePath = "/var/lib/transmission"
        config = {
          bind-address-ipv4            = "0.0.0.0"
          blocklist-enabled            = true
          blocklist-url                = "http://list.iblocklist.com/?list=ydxerpxkpcfqjaybcssw&fileformat=p2p&archiveformat=gz"
          download-dir                 = "/var/lib/transmission/downloads"
          incomplete-dir               = "/var/lib/transmission/incomplete"
          incomplete-dir-enabled       = true
          download-queue-enabled       = true
          download-queue-size          = 20
          encryption                   = 2
          max-peers-global             = 1000
          message-level                = 2
          peer-limit-global            = 1000
          peer-limit-per-torrent       = 1000
          port-forwarding-enabled      = false
          preallocation                = 0
          queue-stalled-enabled        = true
          queue-stalled-minutes        = 5
          ratio-limit                  = 0
          ratio-limit-enabled          = true
          rename-partial-files         = true
          rpc-authentication-required  = false
          rpc-host-whitelist-enabled   = false
          rpc-port                     = local.service_ports.transmission
          rpc-url                      = "/transmission/"
          rpc-whitelist-enabled        = false
          script-torrent-done-enabled  = true
          script-torrent-done-filename = "/torrentdone.sh"
          speed-limit-down-enabled     = false
          speed-limit-up               = 10
          speed-limit-up-enabled       = true
          start-added-torrents         = true
        }
        doneScript = <<EOF
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
      }
      # Add local routes https://hub.docker.com/r/linuxserver/wireguard
      wireguard = {
        enabled = true
        config = {
          Interface = merge({
            for k, v in var.wireguard_client.Interface :
            k => v
            if k != "DNS"
            }, {
            PostUp = <<EOT
nft add table ip filter && nft add chain ip filter output { type filter hook output priority 0 \; } && nft insert rule ip filter output oifname != "%i" mark != $(wg show %i fwmark) fib daddr type != local ip daddr != ${local.networks.kubernetes_service.prefix} ip daddr != ${local.networks.kubernetes_pod.prefix} reject && ip route add ${local.networks.kubernetes_service.prefix} via $(ip route | grep default | awk '{print $3}')
EOT
          })
          Peer = merge(var.wireguard_client.Peer, {
            PersistentKeepalive = 25
          })
        }
      }
    }),
  ]
}

# vaultwarden #

resource "helm_release" "vaultwarden" {
  name  = "vaultwarden"
  chart = "${path.module}/output/charts/vaultwarden"
  wait  = false
}

# hostapd #

resource "helm_release" "hostapd" {
  name  = "hostapd"
  chart = "${path.module}/output/charts/hostapd"
  wait  = false
}

# alpaca stream broadcast #

resource "helm_release" "alpaca-stream" {
  name       = "alpaca-stream-server"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "stream-server"
  version    = "0.1.7"
  wait       = false
  values = [
    yamlencode({
      images = {
        stream_server = local.container_images.alpaca_stream
      }
      service = {
        type = "LoadBalancer"
        port = local.service_ports.alpaca_stream
        externalIPs = [
          local.services.alpaca_stream.ip,
        ]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.kubernetes_ingress_endpoints.alpaca_stream
        }
      }
      alpaca_api_key_id     = var.alpaca.api_key_id
      alpaca_api_secret_key = var.alpaca.api_secret_key
      alpaca_api_base_url   = var.alpaca.api_base_url
    }),
  ]
}

# code-server #

resource "helm_release" "code" {
  name       = "code"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "code"
  wait       = false
  version    = "0.1.23"
  values = [
    yamlencode({
      images = {
        code      = local.container_images.code_server
        tailscale = local.container_images.tailscale
      }
      user = "code"
      uid  = 10000
      sshKnownHosts = [
        "@cert-authority * ${data.terraform_remote_state.sr.outputs.ssh_ca.public_key_openssh}"
      ]
      code = {
        resources = {
          limits = {
            "github.com/fuse" = 1
            "nvidia.com/gpu"  = 1
          }
        }
      }
      tailscale = {
        authKey = var.tailscale.auth_key
        ssm = {
          awsRegion       = data.terraform_remote_state.sr.outputs.ssm.tailscale.aws_region
          accessKeyID     = data.terraform_remote_state.sr.outputs.ssm.tailscale.access_key_id
          secretAccessKey = data.terraform_remote_state.sr.outputs.ssm.tailscale.secret_access_key
          resource        = data.terraform_remote_state.sr.outputs.ssm.tailscale.resource
        }
        additionalEnvs = {
          TS_ACCEPT_DNS          = true
          TS_DEBUG_FIREWALL_MODE = "nftables"
          TS_EXTRA_ARGS = [
            "--advertise-exit-node",
          ]
          TS_ROUTES = [
            local.networks.lan.prefix,
            local.networks.service.prefix,
            local.networks.kubernetes.prefix,
            local.networks.kubernetes_service.prefix,
            local.networks.kubernetes_pod.prefix,
          ]
        }
      }
      ports = {
        code = local.service_ports.code_server
      }
      service = {
        type = "ClusterIP"
        port = local.service_ports.code_server
      }
      ingress = {
        enabled          = true
        ingressClassName = local.ingress_classes.ingress_nginx
        path             = "/"
        annotations      = local.nginx_ingress_annotations
        tls = [
          local.tls_wildcard,
        ]
        hosts = [
          local.kubernetes_ingress_endpoints.code_server,
        ]
      }
      persistence = {
        accessMode   = "ReadWriteOnce"
        storageClass = "local-path"
        size         = "128Gi"
      }
    }),
  ]
}

# kasm-desktop #
/*
resource "helm_release" "desktop" {
  name       = "desktop"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "desktop"
  wait       = false
  version    = "0.2.3"
  values = [
    yamlencode({
      images = {
        desktop = local.container_images.kasm_desktop
      }
      user          = "kasm-user"
      uid           = 10000
      sshKnownHosts = [
        "@cert-authority * ${data.terraform_remote_state.sr.outputs.ssh_ca.public_key_openssh}"
      ]
      kasm = {
        display = ":0"
        additionalEnvs = {
          VK_ICD_FILENAMES = "/usr/share/vulkan/icd.d/radeon_icd.i686.json:/usr/share/vulkan/icd.d/radeon_icd.x86_64.json"
          AMD_VULKAN_ICD   = "RADV"
          RESOLUTION       = "2560x1600"
        }
        resources = {
          limits = {
            "github.com/fuse" = 1
            "amd.com/gpu"     = 1
          }
        }
      }
      ports = {
        kasm = local.service_ports.kasm_desktop
      }
      kasmService = {
        type = "ClusterIP"
        port = local.service_ports.kasm_desktop
      }
      sunshineService = {
        type = "LoadBalancer"
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.kubernetes_ingress_endpoints.kasm_sunshine
        }
        externalIPs = [
          local.services.kasm_sunshine.ip,
        ]
      }
      kasmIngress = {
        enabled          = true
        ingressClassName = local.ingress_classes.ingress_nginx
        path             = "/"
        annotations      = local.nginx_ingress_annotations
        tls = [
          local.tls_wildcard,
        ]
        hosts = [
          local.kubernetes_ingress_endpoints.kasm_desktop,
        ]
      }
      persistence = {
        accessMode   = "ReadWriteOnce"
        storageClass = "local-path"
        size         = "128Gi"
      }
    }),
  ]
}
*/
