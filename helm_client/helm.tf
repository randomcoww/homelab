resource "helm_release" "local" {
  for_each = {
    for f in fileset("./output/charts", "*/values.yaml") :
    dirname(f) => {
      namespace = yamldecode(file("./output/charts/${f}")).Release.Namespace
      chart     = "./output/charts/${dirname(f)}"
      values    = file("./output/charts/${f}")
    }
  }
  name             = each.key
  namespace        = each.value.namespace
  chart            = each.value.chart
  create_namespace = true
  wait             = false
  timeout          = 300
  values = [
    each.value.values
  ]
}

# local-storage storage class #

resource "helm_release" "local-path-provisioner" {
  name       = "local-path-provisioner"
  namespace  = "kube-system"
  repository = "https://charts.containeroo.ch"
  chart      = "local-path-provisioner"
  wait       = false
  version    = "0.0.24"
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
  name       = "amd-gpu"
  repository = "https://radeonopencompute.github.io/k8s-device-plugin/"
  chart      = "amd-gpu"
  namespace  = "kube-system"
  wait       = false
  version    = "0.10.0"
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
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"
  wait       = false
  version    = "0.14.3"
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
  version          = "4.9.0"
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
  name       = "cloudflare-tunnel"
  namespace  = "default"
  repository = "https://cloudflare.github.io/helm-charts/"
  chart      = "cloudflare-tunnel"
  wait       = false
  version    = "0.2.0"
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
            service  = "https://${local.kubernetes_service_endpoints.ingress_nginx_external}"
          },
        ]
      }
      image = {
        repository = split(":", local.container_images.cloudflared)[0]
        tag        = split(":", local.container_images.cloudflared)[1]
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
  version          = "1.12.1"
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
  name      = "cert-issuer"
  chart     = "./local/helm-wrapper"
  namespace = "cert-manager"
  wait      = false
  values = [
    yamlencode({
      manifests = [
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
  wait             = false
  timeout          = 600
  version          = "5.0.14"
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
      # ingress = {
      #   enabled          = true
      #   ingressClassName = local.ingress_classes.ingress_nginx
      #   annotations      = local.nginx_ingress_annotations
      #   tls = [
      #     local.tls_wildcard,
      #   ]
      #   hosts = [
      #     local.kubernetes_ingress_endpoints.minio,
      #   ]
      # }
      environment = {
        MINIO_API_REQUESTS_DEADLINE  = "2m"
        MINIO_STORAGE_CLASS_STANDARD = "EC:2"
        MINIO_STORAGE_CLASS_RRS      = "EC:2"
      }
      buckets = [
        for bucket in local.minio_buckets :
        merge(bucket, {
          purge      = false
          versioning = false
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

# mayastor #
/*
resource "helm_release" "mayastor" {
  name             = "mayastor"
  namespace        = "mayastor"
  repository       = "https://openebs.github.io/mayastor-extensions/"
  chart            = "mayastor"
  create_namespace = true
  wait             = false
  version          = "2.5.0"
  values = [
    yamlencode({
      base = {
        metrics = {
          enabled = false
        }
        jaeger = {
          enabled = false
        }
      }
      etcd = {
        clusterDomain = local.domains.kubernetes
        persistence = {
          storageClass = "local-path"
        }
      }
      eventing = {
        enabled = false
      }
      loki-stack = {
        enabled = false
      }
      obs = {
        callhome = {
          enabled = false
        }
      }
    }),
  ]
}
*/