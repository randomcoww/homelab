# webdav for minio #
/*
resource "helm_release" "webdav" {
  name       = split(".", local.kubernetes_service_endpoints.webdav)[0]
  namespace  = split(".", local.kubernetes_service_endpoints.webdav)[1]
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "webdav"
  version    = "0.1.5"
  wait       = false
  values = [
    yamlencode({
      images = {
        rclone = local.container_images.rclone
      }
      replicaCount  = 2
      minioEndPoint = "http://${local.kubernetes_service_endpoints.minio}:${local.ports.minio}"
      minioBucket   = local.minio_buckets.ebook.name
      affinity = {
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      "webdav",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        annotations      = local.nginx_ingress_annotations
        tls = [
          {
            secretName = "webdav-tls"
            hosts = [
              local.kubernetes_ingress_endpoints.webdav,
            ]
          },
        ]
        hosts = [
          local.kubernetes_ingress_endpoints.webdav,
        ]
      }
    }),
  ]
}
*/

# mpd #

resource "helm_release" "mpd" {
  name       = "mpd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "mpd"
  version    = "0.4.6"
  wait       = false
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
      minioEndPoint = "http://${local.kubernetes_service_endpoints.minio}:${local.ports.minio}"
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
        ingressClassName = "nginx"
        annotations      = local.nginx_ingress_annotations
        tls = [
          {
            secretName = "mpd-tls"
            hosts = [
              local.kubernetes_ingress_endpoints.mpd,
            ]
          },
        ]
        hosts = [
          local.kubernetes_ingress_endpoints.mpd,
        ]
      }
      uiIngress = {
        enabled          = true
        ingressClassName = "nginx"
        path             = "/"
        annotations      = local.nginx_ingress_annotations
        tls = [
          {
            secretName = "mpd-tls"
            hosts = [
              local.kubernetes_ingress_endpoints.mpd,
            ]
          },
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
  version    = "0.1.7"
  wait       = false
  values = [
    yamlencode({
      persistence = {
        accessMode   = "ReadWriteOnce"
        storageClass = "local-path"
        size         = "32Gi"
      }
      images = {
        transmission = local.container_images.transmission
        wireguard    = local.container_images.wireguard
      }
      ports = {
        transmission = local.ports.transmission
      }
      service = {
        type = "ClusterIP"
        port = local.ports.transmission
      }
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        path             = "/"
        annotations      = local.nginx_ingress_annotations
        tls = [
          {
            secretName = "transmission-tls"
            hosts = [
              local.kubernetes_ingress_endpoints.transmission,
            ]
          },
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
          rpc-port                     = local.ports.transmission
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

transmission-remote 127.0.0.1:${local.ports.transmission} \
  --torrent "$TR_TORRENT_ID" \
  --verify

minio-client \
  -endpoint="${local.kubernetes_service_endpoints.minio}:${local.ports.minio}" \
  -bucket="${local.minio_buckets.downloads.name}" \
  -access-key-id="${random_password.minio-access-key-id.result}" \
  -secret-access-key="${random_password.minio-secret-access-key.result}" \
  -path="$TR_TORRENT_NAME"

transmission-remote 127.0.0.1:${local.ports.transmission} \
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

resource "aws_iam_user" "vaultwarden-backup" {
  name = local.vaultwarden.backup_user
}

resource "aws_iam_user_policy" "vaultwarden-backup" {
  name = aws_iam_user.vaultwarden-backup.name
  user = aws_iam_user.vaultwarden-backup.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          "arn:aws:s3:::${local.vaultwarden.backup_bucket}",
          "arn:aws:s3:::${local.vaultwarden.backup_bucket}/${local.vaultwarden.backup_path}",
          "arn:aws:s3:::${local.vaultwarden.backup_bucket}/${local.vaultwarden.backup_path}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_access_key" "vaultwarden-backup" {
  user = aws_iam_user.vaultwarden-backup.name
}

resource "helm_release" "vaultwarden" {
  name       = "vaultwarden"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "vaultwarden"
  version    = "0.1.9"
  wait       = false
  values = [
    yamlencode({
      images = {
        vaultwarden = local.container_images.vaultwarden
        litestream  = local.container_images.litestream
      }
      service = {
        type = "ClusterIP"
        port = local.ports.vaultwarden
      }
      domain = "https://${local.kubernetes_ingress_endpoints.vaultwarden}"
      backup = {
        accessKeyID     = aws_iam_access_key.vaultwarden-backup.id
        secretAccessKey = aws_iam_access_key.vaultwarden-backup.secret
        s3Resource      = "${local.vaultwarden.backup_bucket}/${local.vaultwarden.backup_path}/db.sqlite3"
      }
      vaultwarden = {
        SENDS_ALLOWED            = false
        EMERGENCY_ACCESS_ALLOWED = false
        PASSWORD_HINTS_ALLOWED   = false
        SIGNUPS_ALLOWED          = false
      }
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        path             = "/"
        annotations = merge(local.nginx_ingress_annotations, {
          "nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600"
          "nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600"
        })
        tls = [
          {
            secretName = "vaultwarden-tls"
            hosts = [
              local.kubernetes_ingress_endpoints.vaultwarden,
            ]
          },
        ]
        hosts = [
          local.kubernetes_ingress_endpoints.vaultwarden,
        ]
      }
    }),
  ]
}

# External tunnel #

resource "helm_release" "cloudflare_tunnel" {
  name       = "cloudflare-tunnel"
  namespace  = "default"
  repository = "https://cloudflare.github.io/helm-charts/"
  chart      = "cloudflare-tunnel"
  version    = "0.2.0"
  wait       = false
  values = [
    yamlencode({
      cloudflare = {
        account    = var.cloudflare.account_id
        tunnelName = cloudflare_tunnel.homelab.name
        tunnelId   = cloudflare_tunnel.homelab.id
        secret     = cloudflare_tunnel.homelab.secret
        ingress = [
          {
            hostname = "*.${local.domains.internal}"
            service  = "https://${local.kubernetes_service_endpoints.nginx}"
          },
        ]
      }
      image = {
        tag = "2023.6.0-amd64"
      }
    }),
  ]
}