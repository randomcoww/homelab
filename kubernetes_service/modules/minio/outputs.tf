
output "flux_manifests" {
  value = [
    for _, m in [
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = "${var.name}-resources"
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "https://randomcoww.github.io/homelab/"
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = "${var.name}-resources"
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart = "helm-wrapper"
              sourceRef = {
                kind = "HelmRepository"
                name = "${var.name}-resources"
              }
              interval = "5m"
            }
          }
          releaseName = "${var.name}-resources"
          install = {
            remediation = {
              retries = -1
            }
          }
          upgrade = {
            remediation = {
              retries = -1
            }
          }
          test = {
            enable = true
          }
          values = {
            manifests = [
              module.minio-tls.manifest,
              module.minio-metrics-proxy.manifest,
            ]
          }
        }
      },

      # main
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "https://charts.min.io/"
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart   = "minio"
              version = "5.4.0"
              sourceRef = {
                kind = "HelmRepository"
                name = var.name
              }
              interval = "5m"
            }
          }
          releaseName = var.name
          install = {
            remediation = {
              retries = -1
            }
          }
          upgrade = {
            remediation = {
              retries = -1
            }
          }
          test = {
            enable = true
          }
          values = {
            image = {
              repository = var.images.minio.repository
              tag        = var.images.minio.tag
            }
            podAnnotations = {
              "checksum/tls"           = sha256(module.minio-tls.manifest)
              "checksum/metrics-proxy" = sha256(module.minio-metrics-proxy.manifest)
            }
            clusterDomain     = var.cluster_domain
            mode              = "distributed"
            rootUser          = var.minio_credentials.access_key_id
            rootPassword      = var.minio_credentials.secret_access_key
            priorityClassName = "system-node-critical"
            persistence = {
              storageClass = "local-path"
            }
            drivesPerNode = 1
            replicas      = var.replicas
            resources = {
              requests = {
                memory = "8Gi"
              }
              limits = {
                memory = "8Gi"
              }
            }
            service = {
              type              = "LoadBalancer"
              port              = var.ports.minio
              clusterIP         = var.cluster_service_ip
              loadBalancerClass = "kube-vip.io/kube-vip-class"
              annotations = {
                "prometheus.io/scrape"        = "true"
                "prometheus.io/port"          = tostring(var.ports.metrics)
                "prometheus.io/path"          = "/minio/metrics/v3"
                "kube-vip.io/loadbalancerIPs" = var.service_ip
              }
            }
            certsPath = "/opt/minio/certs"
            tls = {
              enabled    = true
              publicCrt  = "tls.crt"
              privateKey = "tls.key"
              certSecret = module.minio-tls.name
            }
            trustedCertsSecret = module.minio-tls.name
            ingress = {
              enabled = false
            }
            environment = {
              MINIO_API_REQUESTS_DEADLINE  = "2m"
              MINIO_STORAGE_CLASS_STANDARD = "EC:2"
              MINIO_STORAGE_CLASS_RRS      = "EC:2"
            }
            buckets        = []
            users          = []
            policies       = []
            customCommands = []
            svcaccts       = []
            extraContainers = [
              # bypass TLS for metrics endpoints
              {
                name  = "${var.name}-metrics-proxy"
                image = var.images.nginx
                ports = [
                  {
                    containerPort = var.ports.metrics
                  },
                ]
                volumeMounts = [
                  {
                    name      = "metrics-proxy-config"
                    mountPath = "/etc/nginx/conf.d/default.conf"
                    subPath   = "nginx-proxy.conf"
                  },
                ]
              },
            ]
            extraVolumes = [
              {
                name = "metrics-proxy-config"
                configMap = {
                  name = module.minio-metrics-proxy.name
                }
              },
            ]
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
                            var.name,
                          ]
                        },
                      ]
                    }
                    topologyKey = "kubernetes.io/hostname"
                  },
                ]
              }
            }
          }
        }
      },
    ] :
    yamlencode(m)
  ]
}