output "releases" {
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
              version = "29.2.1" # renovate: datasource=helm depName=prometheus registryUrl=https://prometheus-community.github.io/helm-charts
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
              global = {
                scrape_interval     = "20s"
                scrape_timeout      = "10s"
                evaluation_interval = "20s"
                external_labels = {
                  replica = "$${POD_NAME}"
                }
              }
              strategy = {
                type = "RollingUpdate"
              }
              persistentVolume = {
                enabled   = false
                mountPath = local.tsdb_path
              }
              emptyDir = {
                medium = "Memory"
              }
              podAnnotations = {
                "checksum/store-tls" = sha256(module.store-tls.manifest)
              }
              sidecarContainers = {
                thanos-querier = {
                  image = var.images.thanos
                  args = [
                    "query",
                    "--query.replica-label=replica",
                    "--http-address=0.0.0.0:${local.ports.thanos_querier}",
                    "--grpc-address=127.0.0.1:50903", # unused
                    "--grpc-client-tls-secure",
                    "--grpc-client-tls-cert=${local.store_tls_path}/tls.crt",
                    "--grpc-client-tls-key=${local.store_tls_path}/tls.key",
                    "--grpc-client-tls-ca=${local.store_tls_path}/ca.crt",
                    <<-EOF
                    --endpoint.sd-config=${yamlencode(local.thanos_querier_sd_config)}
                    EOF
                  ]
                  env = [
                    {
                      name = "POD_NAME"
                      valueFrom = {
                        fieldRef = {
                          fieldPath = "metadata.name"
                        }
                      }
                    },
                  ]
                  ports = [
                    {
                      containerPort = local.ports.thanos_querier
                    },
                  ]
                  volumeMounts = [
                    {
                      name        = "thanos-store-tls"
                      mountPath   = "${local.store_tls_path}/tls.crt"
                      subPathExpr = "$(POD_NAME)-tls.crt"
                    },
                    {
                      name        = "thanos-store-tls"
                      mountPath   = "${local.store_tls_path}/tls.key"
                      subPathExpr = "$(POD_NAME)-tls.key"
                    },
                    {
                      name      = "thanos-store-tls"
                      mountPath = "${local.store_tls_path}/ca.crt"
                      subPath   = "ca.crt"
                    },
                  ]
                  livenessProbe = {
                    httpGet = {
                      scheme = "HTTP"
                      port   = local.ports.thanos_querier
                      path   = "/-/healthy"
                    }
                    initialDelaySeconds = 10
                    timeoutSeconds      = 2
                  }
                  readinessProbe = {
                    httpGet = {
                      scheme = "HTTP"
                      port   = local.ports.thanos_querier
                      path   = "/-/ready"
                    }
                  }
                }
                thanos-sidecar = {
                  image = var.images.thanos
                  args = [
                    "sidecar",
                    "--prometheus.url=http://127.0.0.1:${local.ports.prometheus}",
                    "--tsdb.path=${local.tsdb_path}",
                    "--http-address=0.0.0.0:${local.ports.thanos_sidecar_probe}",
                    "--grpc-address=0.0.0.0:${local.ports.thanos_sidecar}",
                    "--grpc-server-tls-cert=${local.store_tls_path}/tls.crt",
                    "--grpc-server-tls-key=${local.store_tls_path}/tls.key",
                    "--grpc-server-tls-client-ca=${local.store_tls_path}/ca.crt",
                    <<-EOF
                    --objstore.config=${yamlencode(local.thanos_object_config)}
                    EOF
                  ]
                  env = [
                    {
                      name = "POD_NAME"
                      valueFrom = {
                        fieldRef = {
                          fieldPath = "metadata.name"
                        }
                      }
                    },
                    {
                      name = "AWS_ACCESS_KEY_ID"
                      valueFrom = {
                        secretKeyRef = {
                          name = var.minio_access_secret
                          key  = "AWS_ACCESS_KEY_ID"
                        }
                      }
                    },
                    {
                      name = "AWS_SECRET_ACCESS_KEY"
                      valueFrom = {
                        secretKeyRef = {
                          name = var.minio_access_secret
                          key  = "AWS_SECRET_ACCESS_KEY"
                        }
                      }
                    },
                  ]
                  ports = [
                    {
                      containerPort = local.ports.thanos_sidecar
                    },
                  ]
                  volumeMounts = [
                    {
                      name      = "storage-volume"
                      mountPath = local.tsdb_path
                    },
                    {
                      name        = "thanos-store-tls"
                      mountPath   = "${local.store_tls_path}/tls.crt"
                      subPathExpr = "$(POD_NAME)-tls.crt"
                    },
                    {
                      name        = "thanos-store-tls"
                      mountPath   = "${local.store_tls_path}/tls.key"
                      subPathExpr = "$(POD_NAME)-tls.key"
                    },
                    {
                      name      = "thanos-store-tls"
                      mountPath = "${local.store_tls_path}/ca.crt"
                      subPath   = "ca.crt"
                    },
                    {
                      name      = "ca-trust-bundle"
                      mountPath = "/etc/ssl/certs/ca-certificates.crt"
                      readOnly  = true
                    },
                  ]
                  livenessProbe = {
                    httpGet = {
                      scheme = "HTTP"
                      port   = local.ports.thanos_sidecar_probe
                      path   = "/-/healthy"
                    }
                    initialDelaySeconds = 10
                    timeoutSeconds      = 2
                  }
                  readinessProbe = {
                    httpGet = {
                      scheme = "HTTP"
                      port   = local.ports.thanos_sidecar_probe
                      path   = "/-/ready"
                    }
                  }
                }
                thanos-store = {
                  image = var.images.thanos
                  args = [
                    "store",
                    "--data-dir=${local.store_data_path}",
                    "--http-address=0.0.0.0:${local.ports.thanos_store_probe}",
                    "--grpc-address=0.0.0.0:${local.ports.thanos_store}",
                    "--grpc-server-tls-cert=${local.store_tls_path}/tls.crt",
                    "--grpc-server-tls-key=${local.store_tls_path}/tls.key",
                    "--grpc-server-tls-client-ca=${local.store_tls_path}/ca.crt",
                    <<-EOF
                    --objstore.config=${yamlencode(local.thanos_object_config)}
                    EOF
                  ]
                  env = [
                    {
                      name = "POD_NAME"
                      valueFrom = {
                        fieldRef = {
                          fieldPath = "metadata.name"
                        }
                      }
                    },
                    {
                      name = "AWS_ACCESS_KEY_ID"
                      valueFrom = {
                        secretKeyRef = {
                          name = var.minio_access_secret
                          key  = "AWS_ACCESS_KEY_ID"
                        }
                      }
                    },
                    {
                      name = "AWS_SECRET_ACCESS_KEY"
                      valueFrom = {
                        secretKeyRef = {
                          name = var.minio_access_secret
                          key  = "AWS_SECRET_ACCESS_KEY"
                        }
                      }
                    },
                  ]
                  ports = [
                    {
                      containerPort = local.ports.thanos_store
                    },
                  ]
                  volumeMounts = [
                    {
                      name      = "thanos-store-data"
                      mountPath = local.store_data_path
                    },
                    {
                      name        = "thanos-store-tls"
                      mountPath   = "${local.store_tls_path}/tls.crt"
                      subPathExpr = "$(POD_NAME)-tls.crt"
                    },
                    {
                      name        = "thanos-store-tls"
                      mountPath   = "${local.store_tls_path}/tls.key"
                      subPathExpr = "$(POD_NAME)-tls.key"
                    },
                    {
                      name      = "thanos-store-tls"
                      mountPath = "${local.store_tls_path}/ca.crt"
                      subPath   = "ca.crt"
                    },
                    {
                      name      = "ca-trust-bundle"
                      mountPath = "/etc/ssl/certs/ca-certificates.crt"
                      readOnly  = true
                    },
                  ]
                  livenessProbe = {
                    httpGet = {
                      scheme = "HTTP"
                      port   = local.ports.thanos_store_probe
                      path   = "/-/healthy"
                    }
                    initialDelaySeconds = 10
                    timeoutSeconds      = 2
                  }
                  readinessProbe = {
                    httpGet = {
                      scheme = "HTTP"
                      port   = local.ports.thanos_store_probe
                      path   = "/-/ready"
                    }
                  }
                }
              }
              replicaCount = var.replicas
              statefulSet = {
                enabled = true
                headless = {
                  gRPC = {
                    enabled = true
                  }
                }
              }
              storagePath = local.tsdb_path
              extraFlags = [
                "web.enable-lifecycle",
              ]
              extraArgs = {
                enable-feature                    = "expand-external-labels"
                "storage.tsdb.min-block-duration" = "2h"
                "storage.tsdb.max-block-duration" = "2h"
              }
              env = [
                {
                  name = "POD_NAME"
                  valueFrom = {
                    fieldRef = {
                      fieldPath = "metadata.name"
                    }
                  }
                },
              ]
              retention = "6h"
              resources = {
                requests = {
                  memory = "6Gi"
                }
                limits = {
                  memory = "6Gi"
                }
              }
              service = {
                enabled = true
                additionalPorts = [
                  {
                    name       = "thanos-querier"
                    port       = local.ports.thanos_querier
                    targetPort = local.ports.thanos_querier
                  },
                ]
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
                  additionalRules = [
                    {
                      matches = [
                        for _, p in [
                          "/api/v1/query",
                          "/api/v1/query_range",
                          "/api/v1/series",
                          "/api/v1/labels",
                          "/api/v1/label",
                          "/api/v1/metadata",
                          "/api/v1/query_exemplars",
                          "/api/v1/rules",
                          "/api/v1/alerts",
                        ] :
                        {
                          path = {
                            type  = "PathPrefix"
                            value = p
                          }
                        }
                      ]
                      backendRefs = [
                        {
                          name = "${var.name}-server"
                          port = local.ports.thanos_querier
                        },
                      ]
                    },
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
                {
                  name = "thanos-store-data"
                  emptyDir = {
                    medium = "Memory"
                  }
                },
                {
                  name = "thanos-store-tls"
                  secret = {
                    secretName = module.store-tls.name
                  }
                },
              ]
              dnsConfig = {
                options = [
                  {
                    name  = "ndots"
                    value = "2"
                  },
                ]
              }
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
            extraManifests = [
              module.store-tls.manifest,
              yamlencode(local.compactor_job),
            ]
            extraScrapeConfigs = var.scrape_configs
            serverFiles        = var.server_files
            alertmanager = {
              enabled = false
            }
            kube-state-metrics = {
              enabled = false
            }
            prometheus-node-exporter = {
              enabled = true
              resources = {
                requests = {
                  memory = "64Mi"
                }
                limits = {
                  memory = "64Mi"
                }
              }
            }
            prometheus-pushgateway = {
              enabled = false
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