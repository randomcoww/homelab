locals {
  modules_enabled = [
    module.transmission,
    module.alpaca-stream,
    module.hostapd,
    module.code,
    module.vaultwarden,
    module.authelia,
    module.kube-dns,
    module.kea,
    module.flannel,
    module.kapprover,
    module.fuse-device-plugin,
    module.matchbox,
    module.bootstrap,
    module.kube-proxy,
    module.lldap,
    # module.mpd,
    # module.headscale,
    # module.kasm-desktop,
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
}

# local-storage storage class #

resource "helm_release" "local-path-provisioner" {
  name        = "local-path-provisioner"
  namespace   = "kube-system"
  repository  = "https://charts.containeroo.ch"
  chart       = "local-path-provisioner"
  wait        = false
  version     = "0.0.25"
  max_history = 2
  values = [
    yamlencode({
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
}

# amd device plugin #

resource "helm_release" "amd-gpu" {
  name        = "amd-gpu"
  repository  = "https://rocm.github.io/k8s-device-plugin/"
  chart       = "amd-gpu"
  namespace   = "kube-system"
  wait        = false
  version     = "0.11.0"
  max_history = 2
  values = [
    yamlencode({
      tolerations = [
        {
          key      = "node-role.kubernetes.io/de"
          operator = "Exists"
        },
      ]
    }),
  ]
}

# nvidia device plugin #

resource "helm_release" "nvidia-device-plugin" {
  name        = "nvidia-device-plugin"
  repository  = "https://nvidia.github.io/k8s-device-plugin"
  chart       = "nvidia-device-plugin"
  namespace   = "kube-system"
  wait        = false
  version     = "0.14.3"
  max_history = 2
  values = [
    yamlencode({
      tolerations = [
        {
          key      = "node-role.kubernetes.io/de"
          operator = "Exists"
        },
      ]
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "nvidia"
                    operator = "Exists"
                  },
                ]
              },
            ]
          }
        }
      }
    }),
  ]
}

# nginx ingress #

resource "helm_release" "ingress-nginx" {
  for_each = local.ingress_classes

  name             = each.value
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = split(".", local.kubernetes_service_endpoints[each.key])[1]
  create_namespace = true
  wait             = false
  version          = "4.9.1"
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
          ignore-invalid-headers = "off"
          proxy-body-size        = 0
          proxy-buffering        = "off"
          ssl-redirect           = "true"
          use-forwarded-headers  = "true"
          keep-alive             = "false"
        }
      }
    }),
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
            hostname = "*.${local.domains.internal}"
            service  = "https://${local.kubernetes_service_endpoints.ingress_nginx_external}"
          },
        ]
      }
    }),
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
  version          = "1.13.3"
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
    }),
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
                        local.domains.internal,
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
                        local.domains.internal,
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
  name             = split(".", local.kubernetes_service_endpoints.minio)[0]
  namespace        = split(".", local.kubernetes_service_endpoints.minio)[1]
  repository       = "https://charts.min.io/"
  chart            = "minio"
  create_namespace = true
  wait             = true
  timeout          = 600
  version          = "5.0.15"
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
      drivesPerNode = 2
      replicas      = 3
      resources = {
        requests = {
          memory = "8Gi"
        }
      }
      service = {
        type = "LoadBalancer"
        port = local.service_ports.minio
        externalIPs = [
          local.services.minio.ip,
        ]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.kubernetes_ingress_endpoints.minio
        }
      }
      ingress = {
        enabled          = false
        ingressClassName = local.ingress_classes.ingress_nginx
        annotations      = local.nginx_ingress_annotations
        tls = [
          local.ingress_tls_common,
        ]
        hosts = [
          local.kubernetes_ingress_endpoints.minio,
        ]
      }
      environment = {
        MINIO_API_REQUESTS_DEADLINE  = "2m"
        MINIO_STORAGE_CLASS_STANDARD = "EC:2"
        MINIO_STORAGE_CLASS_RRS      = "EC:2"
      }
      buckets = [
        for bucket in local.minio_buckets :
        merge(bucket, {
          purge         = false
          versioning    = false
          objectlocking = false
        })
      ]
      users          = []
      policies       = []
      customCommands = []
      svcaccts       = []
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "minio"
                    operator = "Exists"
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
}

# openspeedtest #
/*
resource "helm_release" "speedtest" {
  name        = "speedtest"
  repository  = "https://openspeedtest.github.io/Helm-chart/"
  chart       = "openspeedtest"
  wait        = false
  version     = "0.1.2"
  max_history = 2
  values = [
    yamlencode({
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled     = true
        className   = local.ingress_classes.ingress_nginx
        annotations = local.nginx_ingress_auth_annotations
        tls = [
          local.ingress_tls_common,
        ]
        hosts = [
          {
            host = local.kubernetes_ingress_endpoints.speedtest
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
              },
            ]
          },
        ]
      }
    })
  ]
}
*/