output "flux_manifests" {
  value = [
    for _, m in [
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "https://prometheus-community.github.io/helm-charts"
        }
      },

      # prometheus
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
              chart   = "prometheus"
              version = "28.14.0" # renovate: datasource=helm depName=prometheus registryUrl=https://prometheus-community.github.io/helm-charts
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
            enable = false
          }
          values = {

            # manifest start

            configmapReload = {
              prometheus = {
                enabled = true
              }
            }
            server = {
              strategy = {
                type = "RollingUpdate"
              }
              persistentVolume = {
                enabled = false
              }
              replicaCount = 2
              statefulSet = {
                enabled = true
              }
              global = {
                scrape_interval     = "10s"
                scrape_timeout      = "4s"
                evaluation_interval = "10s"
              }
              extraFlags = [
                "web.enable-lifecycle",
                "storage.tsdb.wal-compression",
              ]
              retention     = "1d"
              retentionSize = "128MB"
              resources = {
                requests = {
                  memory = "4Gi"
                }
                limits = {
                  memory = "4Gi"
                }
              }
              ingress = {
                enabled = false
              }
              route = {
                main = {
                  enabled = true
                  parentRefs = [
                    var.gateway_ref,
                  ]
                  hostnames = [
                    var.ingress_hostname,
                  ]
                }
              }
              extraVolumeMounts = [
                {
                  name      = "ca-trust-bundle"
                  mountPath = "/etc/ssl/certs/ca-certificates.crt"
                  readOnly  = true
                },
              ]
              extraVolumes = [
                {
                  name = "ca-trust-bundle"
                  hostPath = {
                    path = "/etc/ssl/certs/ca-certificates.crt"
                    type = "File"
                  }
                },
              ]
              podLabels = {
                app = var.name
              }
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
            extraScrapeConfigs = var.scrape_configs
            serverFiles        = var.server_files
            alertmanager = {
              enabled = false
            }
            kube-state-metrics = {
              enabled = false
            }
            prometheus-node-exporter = {
              enabled = false
            }
            prometheus-pushgateway = {
              enabled = false
            }
          }
        }
      },

      # node exporter
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = "${var.name}-node-exporter"
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart   = "prometheus-node-exporter"
              version = "4.52.1" # renovate: datasource=helm depName=prometheus-node-exporter registryUrl=https://prometheus-community.github.io/helm-charts
              sourceRef = {
                kind = "HelmRepository"
                name = var.name
              }
              interval = "5m"
            }
          }
          releaseName = "${var.name}-node-exporter"
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
            enable = false
          }
          values = {
            resources = {
              requests = {
                memory = "64Mi"
              }
              limits = {
                memory = "64Mi"
              }
            }
          }
        }
      },

      # systemd exporter
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = "${var.name}-systemd-exporter"
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart   = "prometheus-systemd-exporter"
              version = "0.5.2" # renovate: datasource=helm depName=prometheus-systemd-exporter registryUrl=https://prometheus-community.github.io/helm-charts
              sourceRef = {
                kind = "HelmRepository"
                name = var.name
              }
              interval = "5m"
            }
          }
          releaseName = "${var.name}-systemd-exporter"
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
            enable = false
          }
          values = {
            config = {
              systemd = {
                collector = {
                  unitInclude = [
                    "kubelet.service",
                    "crio.service",
                    "keepalived.service",
                    "haproxy.service",
                    "bird.service",
                    "conntrackd.service",
                    "systemd-networkd.service",
                    "systemd-resolved.service",
                    "chronyd.service",
                  ]
                }
              }
            }
            resources = {
              requests = {
                memory = "64Mi"
              }
              limits = {
                memory = "64Mi"
              }
            }
          }
        }
      },
    ] :
    yamlencode(m)
  ]
}