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

# fuse device plugin #

resource "helm_release" "fuse-device-plugin" {
  name             = "fuse-device-plugin"
  repository       = "https://randomcoww.github.io/repos/helm/"
  chart            = "helm-wrapper"
  namespace        = "kube-system"
  create_namespace = true
  wait             = true
  version          = "0.1.0"
  values = [
    yamlencode({
      manifests = [
        {
          apiVersion = "apps/v1"
          kind       = "DaemonSet"
          metadata = {
            name = "fuse-device-plugin-daemonset"
          }
          spec = {
            selector = {
              matchLabels = {
                name = "fuse-device-plugin-ds"
              }
            }
            template = {
              metadata = {
                labels = {
                  name = "fuse-device-plugin-ds"
                }
              }
              spec = {
                hostNetwork = true
                containers = [
                  {
                    image = local.container_images.fuse_device_plugin
                    name  = "fuse-device-plugin-ctr"
                    securityContext = {
                      allowPrivilegeEscalation = false
                      capabilities = {
                        drop = [
                          "ALL",
                        ]
                      },
                    }
                    volumeMounts = [
                      {
                        name      = "device-plugin"
                        mountPath = "/var/lib/kubelet/device-plugins"
                      },
                    ]
                  },
                ]
                volumes = [
                  {
                    name = "device-plugin"
                    hostPath = {
                      path = "/var/lib/kubelet/device-plugins"
                    }
                  },
                ]
                tolerations = [
                  {
                    key      = "node.kubernetes.io/not-ready"
                    operator = "Exists"
                    effect   = "NoExecute"
                  },
                  {
                    key      = "node.kubernetes.io/unreachable"
                    operator = "Exists"
                    effect   = "NoExecute"
                  },
                  {
                    key      = "node.kubernetes.io/disk-pressure"
                    operator = "Exists"
                    effect   = "NoSchedule"
                  },
                  {
                    key      = "node.kubernetes.io/memory-pressure"
                    operator = "Exists"
                    effect   = "NoSchedule"
                  },
                  {
                    key      = "node.kubernetes.io/pid-pressure"
                    operator = "Exists"
                    effect   = "NoSchedule"
                  },
                  {
                    key      = "node.kubernetes.io/unschedulable"
                    operator = "Exists"
                    effect   = "NoSchedule"
                  },
                  {
                    key      = "node-role.kubernetes.io/de"
                    operator = "Exists"
                  },
                ]
              }
            }
          }
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
  version          = "4.6.1"
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
          # externalTrafficPolicy = "Local"
        }
        config = {
          ignore-invalid-headers = "off"
          proxy-body-size        = 0
          proxy-buffering        = "off"
          ssl-redirect           = "true"
          use-forwarded-headers  = "true"
        }
      }
    }),
  ]
}

resource "helm_release" "cloudflare-token" {
  name             = "cloudflare-token"
  repository       = "https://randomcoww.github.io/repos/helm/"
  chart            = "helm-wrapper"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  version          = "0.1.0"
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
      ]
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
  wait             = false
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

resource "helm_release" "cert-issuer-secrets" {
  name             = "cert-issuer-secrets"
  repository       = "https://randomcoww.github.io/repos/helm/"
  chart            = "helm-wrapper"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  version          = "0.1.0"
  values = [
    yamlencode({
      manifests = [
        {
          apiVersion = "v1"
          kind       = "Secret"
          metadata = {
            name = local.cert_issuer_prod
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
            name = local.cert_issuer_staging
          }
          stringData = {
            "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.staging_private_key_pem)
          }
          type = "Opaque"
        },
      ]
    }),
  ]
}

resource "helm_release" "cert-issuer" {
  name       = "cert-issuer"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "helm-wrapper"
  wait       = false
  version    = "0.1.0"
  values = [
    yamlencode({
      manifests = [
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.cert_issuer_prod
          }
          spec = {
            acme = {
              server = "https://acme-v02.api.letsencrypt.org/directory"
              email  = var.letsencrypt.email
              privateKeySecretRef = {
                name = local.cert_issuer_prod
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
            name = local.cert_issuer_staging
          }
          spec = {
            acme = {
              server = "https://acme-staging-v02.api.letsencrypt.org/directory"
              email  = var.letsencrypt.email
              privateKeySecretRef = {
                name = local.cert_issuer_staging
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
    helm_release.cert-issuer-secrets,
  ]
  lifecycle {
    replace_triggered_by = [
      helm_release.cert-manager,
      helm_release.cert-issuer-secrets,
    ]
  }
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