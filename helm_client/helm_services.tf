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
      minioEndPoint = "http://minio.minio:9000"
      minioBucket   = "music"
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
          "nginx.ingress.kubernetes.io/auth-signin"           = "https://${local.ingress_hosts.auth}"
          "nginx.ingress.kubernetes.io/auth-snippet"          = <<EOF
proxy_set_header X-Forwarded-Method $request_method;
EOF
          "nginx.ingress.kubernetes.io/auth-url"              = "http://authelia.authelia.svc.${local.domains.kubernetes}/api/verify"
        }
        tls = [
          {
            secretName = "mpd-tls"
            hosts = [
              local.ingress_hosts.mpd,
            ]
          },
        ]
        hosts = [
          local.ingress_hosts.mpd,
        ]
      }
      uiIngress = {
        enabled          = true
        ingressClassName = "nginx"
        path             = "/"
        annotations = {
          "cert-manager.io/cluster-issuer"                    = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/auth-response-headers" = "Remote-User,Remote-Name,Remote-Groups,Remote-Email"
          "nginx.ingress.kubernetes.io/auth-signin"           = "https://${local.ingress_hosts.auth}"
          "nginx.ingress.kubernetes.io/auth-snippet"          = <<EOF
proxy_set_header X-Forwarded-Method $request_method;
EOF
          "nginx.ingress.kubernetes.io/auth-url"              = "http://authelia.authelia.svc.${local.domains.kubernetes}/api/verify"
        }
        tls = [
          {
            secretName = "mpd-tls"
            hosts = [
              local.ingress_hosts.mpd,
            ]
          },
        ]
        hosts = [
          local.ingress_hosts.mpd,
        ]
      }
    }),
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
