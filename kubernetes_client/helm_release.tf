## Hack to release custom charts as local chart

locals {
  modules_enabled = [
    module.bootstrap,
    module.kube-proxy,
    module.flannel,
    module.kapprover,
    module.kube-dns,
    module.fuse-device-plugin,
    module.kea,
    module.matchbox,
    module.lldap,
    module.vaultwarden,
    module.authelia-redis,
    module.authelia,
    module.tailscale,
    module.hostapd,
    module.qrcode,
    module.alpaca-db,
    # module.alpaca-stream,
    module.code,
    # module.mpd,
    module.transmission,
    module.webdav-pictures,
    module.webdav-videos,
    module.sunshine,
    # module.wireproxy,
  ]
}

resource "helm_release" "wrapper" {
  for_each = {
    for m in local.modules_enabled :
    m.chart.name => m.chart
  }
  chart            = "./local/helm-wrapper"
  name             = each.key
  namespace        = each.value.namespace
  create_namespace = true
  wait             = false
  timeout          = 300
  max_history      = 2
  values = [
    yamlencode({
      manifests = values(each.value.manifests)
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

## Release for public charts

resource "helm_release" "metrics-server" {
  name        = "metrics-server"
  namespace   = "kube-system"
  repository  = "https://kubernetes-sigs.github.io/metrics-server"
  chart       = "metrics-server"
  wait        = false
  version     = "3.12.1"
  max_history = 2
  values = [
    yamlencode({
      replicas = 2
      defaultArgs = [
        "--cert-dir=/tmp",
        "--metric-resolution=15s",
        "--kubelet-preferred-address-types=InternalIP",
        "--kubelet-use-node-status-port",
        "--v=2",
      ]
      dnsConfig = {
        options = [
          {
            name  = "ndots"
            value = "2"
          },
        ]
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# local-storage storage class #

resource "helm_release" "local-path-provisioner" {
  name        = "local-path-provisioner"
  namespace   = "kube-system"
  repository  = "https://charts.containeroo.ch"
  chart       = "local-path-provisioner"
  wait        = false
  version     = "0.0.28"
  max_history = 2
  values = [
    yamlencode({
      replicaCount = 2
      storageClass = {
        name = "local-path"
      }
      nodePathMap = [
        {
          node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = ["${local.mounts.containers_path}/local_path_provisioner"]
        },
      ]
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# nvidia device plugin #

resource "helm_release" "nvidia-device-plugin" {
  name        = "nvidia-device-plugin"
  repository  = "https://nvidia.github.io/k8s-device-plugin"
  chart       = "nvidia-device-plugin"
  namespace   = "kube-system"
  wait        = false
  version     = "0.16.2"
  max_history = 2
  values = [
    yamlencode({
      config = {
        map = {
          default = yamlencode({
            version = "v1"
            sharing = {
              mps = {
                renameByDefault = true
                resources = [
                  {
                    name     = "nvidia.com/gpu"
                    replicas = 10
                  },
                ]
              }
            }
          })
        }
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# nginx ingress #

resource "helm_release" "ingress-nginx" {
  for_each = local.ingress_classes

  name             = each.value
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = local.kubernetes_services[each.key].namespace
  create_namespace = true
  wait             = false
  version          = "4.11.2"
  max_history      = 2
  values = [
    yamlencode({
      controller = {
        kind = "DaemonSet"
        ingressClassResource = {
          enabled         = true
          name            = each.value
          controllerValue = "k8s.io/${each.value}"
        }
        ingressClass = each.value
        service = {
          type = "LoadBalancer"
          externalIPs = [
            local.services[each.key].ip,
          ]
        }
        allowSnippetAnnotations = true
        config = {
          ignore-invalid-headers  = "off"
          proxy-body-size         = 0
          proxy-buffering         = "off"
          proxy-request-buffering = "off"
          ssl-redirect            = "true"
          use-forwarded-headers   = "true"
          keep-alive              = "false"
        }
        controller = {
          dnsConfig = {
            options = [
              {
                name  = "ndots"
                value = "2"
              },
            ]
          }
        }
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# cloudflare tunnel #
/*
resource "helm_release" "cloudflare-tunnel" {
  name        = "cloudflare-tunnel"
  namespace   = "default"
  repository  = "https://cloudflare.github.io/helm-charts/"
  chart       = "cloudflare-tunnel"
  wait        = false
  version     = "0.3.0"
  max_history = 2
  values = [
    yamlencode({
      cloudflare = {
        account    = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.external.account_id
        tunnelName = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.external.name
        tunnelId   = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.external.id
        secret     = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.external.secret
        ingress = [
          {
            hostname = "*.${local.domains.public}"
            service  = "https://${local.kubernetes_services.ingress_nginx_external.endpoint}"
          },
        ]
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}
*/
# cert-manager #

resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  timeout          = 600
  version          = "1.15.1"
  max_history      = 2
  values = [
    yamlencode({
      deploymentAnnotations = {
        "certmanager.k8s.io/disable-validation" = "true"
      }
      installCRDs = true
      prometheus = {
        enabled = false
      }
      extraArgs = [
        "--dns01-recursive-nameservers-only",
        "--dns01-recursive-nameservers=${local.upstream_dns.ip}:53",
      ]
      podDnsConfig = {
        options = [
          {
            name  = "ndots"
            value = "2"
          },
        ]
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

resource "helm_release" "cert-issuer" {
  name        = "cert-issuer"
  chart       = "./local/helm-wrapper"
  namespace   = "cert-manager"
  wait        = false
  max_history = 2
  values = [
    yamlencode({
      manifests = [
        for m in [
          {
            apiVersion = "v1"
            kind       = "Secret"
            metadata = {
              name = "cloudflare-token"
            }
            stringData = {
              token = data.terraform_remote_state.sr.outputs.cloudflare_dns_api_token
            }
            type = "Opaque"
          },
          {
            apiVersion = "v1"
            kind       = "Secret"
            metadata = {
              name = local.kubernetes.cert_issuer_prod
            }
            stringData = {
              "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.private_key_pem)
            }
            type = "Opaque"
          },
          {
            apiVersion = "v1"
            kind       = "Secret"
            metadata = {
              name = local.kubernetes.cert_issuer_staging
            }
            stringData = {
              "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.staging_private_key_pem)
            }
            type = "Opaque"
          },
          {
            apiVersion = "cert-manager.io/v1"
            kind       = "ClusterIssuer"
            metadata = {
              name = local.kubernetes.cert_issuer_prod
            }
            spec = {
              acme = {
                server = "https://acme-v02.api.letsencrypt.org/directory"
                email  = data.terraform_remote_state.sr.outputs.letsencrypt.username
                privateKeySecretRef = {
                  name = local.kubernetes.cert_issuer_prod
                }
                disableAccountKeyGeneration = true
                solvers = [
                  {
                    dns01 = {
                      cloudflare = {
                        apiTokenSecretRef = {
                          name = "cloudflare-token"
                          key  = "token"
                        }
                      }
                    }
                    selector = {
                      dnsZones = [
                        local.domains.public,
                      ]
                    }
                  },
                ]
              }
            }
          },
          {
            apiVersion = "cert-manager.io/v1"
            kind       = "ClusterIssuer"
            metadata = {
              name = local.kubernetes.cert_issuer_staging
            }
            spec = {
              acme = {
                server = "https://acme-staging-v02.api.letsencrypt.org/directory"
                email  = data.terraform_remote_state.sr.outputs.letsencrypt.username
                privateKeySecretRef = {
                  name = local.kubernetes.cert_issuer_staging
                }
                disableAccountKeyGeneration = true
                solvers = [
                  {
                    dns01 = {
                      cloudflare = {
                        apiTokenSecretRef = {
                          name = "cloudflare-token"
                          key  = "token"
                        }
                      }
                    }
                    selector = {
                      dnsZones = [
                        local.domains.public,
                      ]
                    }
                  },
                ]
              }
            }
          },
        ] :
        yamlencode(m)
      ]
    }),
  ]
  depends_on = [
    helm_release.cert-manager,
  ]
}

# minio #

resource "helm_release" "minio" {
  name             = local.kubernetes_services.minio.name
  namespace        = local.kubernetes_services.minio.namespace
  repository       = "https://charts.min.io/"
  chart            = "minio"
  create_namespace = true
  wait             = true
  timeout          = 600
  version          = "5.2.0"
  max_history      = 2
  values = [
    yamlencode({
      clusterDomain = local.domains.kubernetes
      mode          = "distributed"
      rootUser      = data.terraform_remote_state.sr.outputs.minio.access_key_id
      rootPassword  = data.terraform_remote_state.sr.outputs.minio.secret_access_key
      persistence = {
        storageClass = "local-path"
      }
      drivesPerNode = 1
      replicas      = 4
      resources = {
        requests = {
          memory = "16Gi"
        }
      }
      service = {
        type = "LoadBalancer"
        port = local.service_ports.minio
        externalIPs = [
          local.services.minio.ip,
        ]
      }
      ingress = {
        enabled = false
      }
      environment = {
        MINIO_API_REQUESTS_DEADLINE  = "2m"
        MINIO_STORAGE_CLASS_STANDARD = "EC:2"
        MINIO_STORAGE_CLASS_RRS      = "EC:2"
      }
      buckets = [
        for bucket in local.minio_buckets :
        merge({
          purge = false
          # set to anything other than true or false causes bucket to stay un-versioned
          versioning    = "hack-do-not-enable"
          objectlocking = false
        }, bucket)
      ]
      users          = []
      policies       = []
      customCommands = []
      svcaccts       = []
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
                      "minio",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}
