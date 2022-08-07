# mpd #

resource "helm_release" "mpd" {
  name       = "mpd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "mpd"
  version    = "0.3.6"
  wait       = false
  values = [
    yamlencode({
      config = {
        filesystem_charset = "UTF-8"
        auto_update        = "yes"
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
            max_clients = 0
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
            max_clients = 0
          }
        },
      ]
      minioEndPoint = "http://${local.kubernetes_service_endpoints.minio}:${local.ports.minio}"
      minioBucket   = local.minio_buckets.music
      persistence = {
        storageClass = "openebs-jiva-csi-default"
      }
      images = {
        mpd    = local.container_images.mpd
        ympd   = local.container_images.ympd
        rclone = local.container_images.rclone
      }
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        annotations = {
          "cert-manager.io/cluster-issuer"                    = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/auth-response-headers" = "Remote-User,Remote-Name,Remote-Groups,Remote-Email"
          "nginx.ingress.kubernetes.io/auth-signin"           = "https://${local.kubernetes_ingress_endpoints.auth}"
          "nginx.ingress.kubernetes.io/auth-snippet"          = <<EOF
proxy_set_header X-Forwarded-Method $request_method;
EOF
          "nginx.ingress.kubernetes.io/auth-url"              = "http://${local.kubernetes_service_endpoints.authelia}/api/verify"
        }
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
        annotations = {
          "cert-manager.io/cluster-issuer"                    = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/auth-response-headers" = "Remote-User,Remote-Name,Remote-Groups,Remote-Email"
          "nginx.ingress.kubernetes.io/auth-signin"           = "https://${local.kubernetes_ingress_endpoints.auth}"
          "nginx.ingress.kubernetes.io/auth-snippet"          = <<EOF
proxy_set_header X-Forwarded-Method $request_method;
EOF
          "nginx.ingress.kubernetes.io/auth-url"              = "http://${local.kubernetes_service_endpoints.authelia}/api/verify"
        }
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

resource "helm_release" "transmission" {
  name       = "transmission"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "transmission"
  version    = "0.1.7"
  wait       = false
  values = [
    yamlencode({
      persistence = {
        storageClass = "openebs-jiva-csi-default"
        size         = "50Gi"
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
        annotations = {
          "cert-manager.io/cluster-issuer"                    = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/auth-response-headers" = "Remote-User,Remote-Name,Remote-Groups,Remote-Email"
          "nginx.ingress.kubernetes.io/auth-signin"           = "https://${local.kubernetes_ingress_endpoints.auth}"
          "nginx.ingress.kubernetes.io/auth-snippet"          = <<EOF
proxy_set_header X-Forwarded-Method $request_method;
EOF
          "nginx.ingress.kubernetes.io/auth-url"              = "http://${local.kubernetes_service_endpoints.authelia}/api/verify"
        }
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
        # https://unix.stackexchange.com/questions/389705/understanding-the-exec-option-of-find
        # https://unix.stackexchange.com/questions/134693/break-out-of-find-if-an-exec-fails
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

find "$TR_TORRENT_NAME" -type f -exec sh -c 'curl -X PUT -T "$2" $1/$(printf "$2" | jq -sRr @uri) || kill $PPID' \
  sh "http://${local.kubernetes_service_endpoints.minio}:${local.ports.minio}/${local.minio_buckets.transmission}" {} \;

transmission-remote 127.0.0.1:${local.ports.transmission} \
  --torrent "$TR_TORRENT_ID" \
  --remove-and-delete
EOF
      }
      # Add local routes https://hub.docker.com/r/linuxserver/wireguard
      wireguard = {
        enabled = true
        config = {
          Interface = merge(var.wireguard.Interface, {
            PostUp = <<EOT
DROUTE=$(ip route | grep default | awk '{print $3}') && ip route add ${local.networks.kubernetes_service.prefix} via $DROUTE && nft add table ip filter && nft add chain ip filter output { type filter hook output priority 0 \; } && nft insert rule ip filter output oifname != "%i" mark != $(wg show %i fwmark) fib daddr type != local ip daddr != { ${local.networks.kubernetes_service.prefix}, ${local.networks.kubernetes_pod.prefix} } reject
EOT
          })
          Peer = merge(var.wireguard.Peer, {
            PersistentKeepalive = 25
          })
        }
      }
    })
  ]
}

# games on whales https://github.com/games-on-whales #

# resource "helm_release" "gow" {
#   name             = "gow"
#   namespace        = "gow"
#   repository       = "https://k8s-at-home.com/charts/"
#   chart            = "games-on-whales"
#   version          = "1.7.2"
#   wait             = false
#   create_namespace = true
#   values = [
#     yamlencode({
#       ingress = {
#         main = {
#           enabled = false
#         }
#       }
#       service = {
#         main = {
#           annotations = {
#             "metallb.universe.tf/address-pool" = "gow"
#           }
#           type = "LoadBalancer"
#           externalIPs = [
#             local.vips.gow,
#           ]
#         }
#         udp = {
#           annotations = {
#             "metallb.universe.tf/address-pool" = "gow"
#           }
#           type = "LoadBalancer"
#           externalIPs = [
#             local.vips.gow,
#           ]
#         }
#       }
#       persistence = {
#         home = {
#           enabled      = true
#           type         = "pvc"
#           accessMode   = "ReadWriteOnce"
#           size         = "40Gi"
#           storageClass = "local-path"
#         }
#       }
#       resources = {
#         limits = {
#           "amd.com/gpu" = 1
#         }
#       }
#       sunshine = {
#         image = {
#           tag = "edge"
#         }
#       }
#       xorg = {
#         image = {
#           tag = "edge"
#         }
#       }
#       pulseaudio = {
#         image = {
#           tag = "edge"
#         }
#       }
#       steam = {
#         enabled = true
#         image = {
#           tag = "edge"
#         }
#       }
#       retroarch = {
#         enabled = false
#       }
#       firefox = {
#         enabled = false
#       }
#     })
#   ]
# }
