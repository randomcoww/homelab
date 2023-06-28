# webdav for minio #

resource "helm_release" "webdav" {
  name       = split(".", local.kubernetes_service_endpoints.webdav)[0]
  namespace  = split(".", local.kubernetes_service_endpoints.webdav)[1]
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "webdav"
  wait       = false
  version    = "0.1.5"
  values = [
    yamlencode({
      images = {
        rclone = local.container_images.rclone
      }
      replicaCount  = 2
      minioEndPoint = "http://${local.kubernetes_service_endpoints.minio}:${local.ports.minio}"
      minioBucket   = local.minio_buckets.backup.name
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
  wait       = false
  version    = "0.1.7"
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

resource "helm_release" "vaultwarden" {
  name       = "vaultwarden"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "vaultwarden"
  wait       = false
  version    = "0.1.9"
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
        INVITATIONS_ALLOWED      = false
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

# hostapd #

module "hostapd-roaming" {
  source        = "./modules/hostapd_roaming"
  resource_name = "hostapd"
  replica_count = 1
}

resource "helm_release" "hostapd" {
  name       = "hostapd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "hostapd"
  wait       = false
  version    = "0.1.8"
  values = [
    yamlencode({
      image = local.container_images.hostapd
      peers = [
        for _, peer in module.hostapd-roaming.peers :
        {
          podName = peer.pod_name
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
            bssid                 = peer.bssid
            mobility_domain       = peer.mobility_domain
            pmk_r1_push           = 1
            ft_psk_generate_local = 1
            r1_key_holder         = peer.r1_key_holder
            nas_identifier        = peer.nas_identifier
            r0kh = [
              for _, p in module.hostapd-roaming.peers :
              "${p.bssid} ${p.nas_identifier} ${p.encryption_key}"
            ]
            r1kh = [
              for _, p in module.hostapd-roaming.peers :
              "${p.bssid} ${p.bssid} ${p.encryption_key}"
            ]
          }, var.hostapd)
        }
      ]
      StatefulSet = {
        replicaCount = length(module.hostapd-roaming.peers)
      }
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "kubernetes.io/hostname"
                    operator = "In"
                    values = [
                      for _, member in local.members.desktop :
                      member.hostname
                    ]
                  },
                ]
              },
            ]
          }
        }
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      "hostapd",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      tolerations = [
        {
          key      = "node-role.kubernetes.io/de"
          operator = "Exists"
        },
      ]
    }),
  ]
}