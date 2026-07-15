locals {
  store_data_path     = "/thanos/store/data"
  store_tls_path      = "/thanos/store/tls"
  compactor_data_path = "/thanos/compactor/data"
  ports = {
    thanos_querier     = 10906
    thanos_sidecar     = 10901 # 10901-10902 not configurable
    thanos_store       = 10903
    thanos_store_probe = 10905
    prometheus         = 9090 # not configurable
  }

  headless_service = "${var.name}-kube-prometheus-thanos-discovery" # not configurable
  members = [
    for i, _ in range(var.replicas) :
    "${var.name}-prometheus-kube-prometheus-prometheus-${i}.${local.headless_service}.${var.namespace}"
  ]

  # Resolution via SRV is possible but requires TLS by POD_IP which is not supported by cert-manager-csi
  thanos_querier_sd_config = {
    endpoints = concat([
      for _, m in local.members :
      {
        address = "${m}:${local.ports.thanos_sidecar}"
      }
      ], [
      for _, m in local.members :
      {
        address = "${m}:${local.ports.thanos_store}"
      }
    ])
  }

  thanos_object_config = {
    type = "S3"
    config = {
      bucket       = var.minio_bucket
      endpoint     = var.minio_endpoint
      aws_sdk_auth = true
    }
  }

  compactor_job = {
    apiVersion = "batch/v1"
    kind       = "CronJob"
    metadata = {
      name      = "${var.name}-thanos-compactor"
      namespace = var.namespace
      labels = {
        app     = var.name
        release = "0.1.0"
      }
      annotations = {
        "checksum/minio-user-secret" = sha256(module.minio-user-secret.manifest)
      }
    }
    spec = {
      schedule          = "0 * * * *"
      suspend           = false
      concurrencyPolicy = "Forbid"
      jobTemplate = {
        spec = {
          ttlSecondsAfterFinished = 1800
          template = {
            spec = {
              restartPolicy = "Never"
              containers = [
                {
                  name  = "thanos-compactor"
                  image = "${var.images.thanos.registry}/${var.images.thanos.repository}:${var.images.thanos.tag}"
                  args = [
                    "compact",
                    "--web.disable",
                    "--data-dir=${local.compactor_data_path}",
                    "--retention.resolution-raw=40h",
                    "--retention.resolution-5m=10d", # should not be used with downsampling.disable
                    "--retention.resolution-1h=10d", # should not be used with downsampling.disable
                    "--downsampling.disable",
                    <<-EOF
                    --objstore.config=${yamlencode(local.thanos_object_config)}
                    EOF
                  ]
                  env = [
                    {
                      name = "AWS_ACCESS_KEY_ID"
                      valueFrom = {
                        secretKeyRef = {
                          name = module.minio-user-secret.name
                          key  = "AWS_ACCESS_KEY_ID"
                        }
                      }
                    },
                    {
                      name = "AWS_SECRET_ACCESS_KEY"
                      valueFrom = {
                        secretKeyRef = {
                          name = module.minio-user-secret.name
                          key  = "AWS_SECRET_ACCESS_KEY"
                        }
                      }
                    },
                  ]
                  volumeMounts = [
                    {
                      name      = "thanos-compactor-data"
                      mountPath = local.compactor_data_path
                    },
                    {
                      name      = "ca-trust-bundle"
                      mountPath = "/etc/ssl/certs/ca-certificates.crt"
                      readOnly  = true
                    },
                  ]
                },
              ]
              volumes = [
                {
                  name = "thanos-compactor-data"
                  emptyDir = {
                    medium = "Memory"
                  }
                },
                {
                  name = "ca-trust-bundle"
                  hostPath = {
                    path = "/etc/ssl/certs/ca-certificates.crt"
                    type = "File"
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
            }
          }
        }
      }
    }
  }

  values = merge({
    namespaceOverride = var.namespace
    defaultRules = {
      create = true
      rules = {
        alertmanager = false
        windows      = false
      }
    }
    alertmanager = {
      enabled = false
    }
    grafana = {
      enabled = false
    }
    additionalPrometheusRulesMap = merge({
    }, var.extra_rules_map)
    prometheusOperator = {
      enabled = true
      kubeletService = {
        enabled = true
      }
      kubeletEndpointsEnabled     = false
      kubeletEndpointSliceEnabled = true
      thanosImage                 = var.images.thanos
    }
    prometheus = {
      enabled = true
      thanosService = {
        enabled = true
        port    = local.ports.thanos_sidecar
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
                  name = "${var.name}-kube-prometheus-prometheus"
                  port = local.ports.thanos_querier
                },
              ]
            },
          ]
        }
      }
      prometheusSpec = {
        serviceName              = local.headless_service
        disableCompaction        = true
        replicaExternalLabelName = "replica" # value is fixed in thanos
        thanos = {
          objectStorageConfig = {
            secret = {
              type = "S3"
              config = {
                bucket     = var.minio_bucket
                endpoint   = var.minio_endpoint
                access_key = var.minio_user.id
                secret_key = var.minio_user.secret
              }
            }
          }
          grpcServerTlsConfig = {
            certFile = "${local.store_tls_path}/tls.crt"
            keyFile  = "${local.store_tls_path}/tls.key"
            caFile   = "${local.store_tls_path}/ca.crt"
          }
          volumeMounts = [
            {
              name      = "ca-trust-bundle"
              mountPath = "/etc/ssl/certs/ca-certificates.crt"
              readOnly  = true
            },
            {
              name      = "tls"
              mountPath = local.store_tls_path
              readOnly  = true
            },
          ]
        }
        service = {
          enabled    = true
          port       = local.ports.prometheus
          targetPort = local.ports.prometheus
        }
        containers = [
          {
            name  = "thanos-querier"
            image = "${var.images.thanos.registry}/${var.images.thanos.repository}:${var.images.thanos.tag}"
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
              {
                name = "POD_IP"
                valueFrom = {
                  fieldRef = {
                    fieldPath = "status.podIP"
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
                name      = "tls"
                mountPath = local.store_tls_path
                readOnly  = true
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
          },
          {
            name  = "thanos-store"
            image = "${var.images.thanos.registry}/${var.images.thanos.repository}:${var.images.thanos.tag}"
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
                    name = module.minio-user-secret.name
                    key  = "AWS_ACCESS_KEY_ID"
                  }
                }
              },
              {
                name = "AWS_SECRET_ACCESS_KEY"
                valueFrom = {
                  secretKeyRef = {
                    name = module.minio-user-secret.name
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
                name      = "tls"
                mountPath = local.store_tls_path
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
          },
        ]
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "local-path"
              accessModes = [
                "ReadWriteOnce",
              ]
              resources = {
                requests = {
                  storage = "16Gi"
                }
              }
            }
          }
        }
        volumeMounts = [
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        volumes = [
          {
            name = "thanos-store-data"
            emptyDir = {
              medium = "Memory"
            }
          },
          {
            name = "ca-trust-bundle"
            hostPath = {
              path = "/etc/ssl/certs/ca-certificates.crt"
              type = "File"
            }
          },
          {
            name = "tls"
            csi = {
              driver   = "csi.cert-manager.io"
              readOnly = true
              volumeAttributes = {
                "csi.cert-manager.io/issuer-name" = var.name
                "csi.cert-manager.io/issuer-kind" = "Issuer"
                "csi.cert-manager.io/dns-names" = join(",", [
                  "$${POD_NAME}.${local.headless_service}.$${POD_NAMESPACE}",
                ])
                "csi.cert-manager.io/key-algorithm" = "ECDSA"
                "csi.cert-manager.io/key-size"      = "521"
                "csi.cert-manager.io/key-usages" = join(",", [
                  "digital signature",
                  "key encipherment",
                ])
              }
            }
          },
        ]
        retention = "6h"
        resources = {
          requests = {
            memory = "6Gi"
          }
        }
        replicas = var.replicas
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
        additionalScrapeConfigs = concat(yamldecode(<<-EOF
          - job_name: kubernetes-service-endpoints
            honor_labels: true
            kubernetes_sd_configs:
              - role: endpointslice
            relabel_configs:
              - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
                action: keep
                regex: true
              - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape_slow]
                action: drop
                regex: true
              - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
                action: replace
                target_label: __scheme__
                regex: (https?)
              - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
                action: replace
                target_label: __metrics_path__
                regex: (.+)
              - source_labels:
                - __address__
                - __meta_kubernetes_service_annotation_prometheus_io_port
                action: replace
                target_label: __address__
                regex: (.+?)(?::\d+)?;(\d+)
                replacement: $1:$2
              - action: labelmap
                regex: __meta_kubernetes_service_annotation_prometheus_io_param_(.+)
                replacement: __param_$1
              - action: labelmap
                regex: __meta_kubernetes_service_label_(.+)
              - source_labels: [__meta_kubernetes_namespace]
                action: replace
                target_label: namespace
              - source_labels: [__meta_kubernetes_service_name]
                action: replace
                target_label: service
              - source_labels: [__meta_kubernetes_pod_node_name]
                action: replace
                target_label: node

          - job_name: kubernetes-pods
            honor_labels: true
            kubernetes_sd_configs:
              - role: pod
            relabel_configs:
              - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
                action: keep
                regex: true
              - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape_slow]
                action: drop
                regex: true
              - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scheme]
                action: replace
                regex: (https?)
                target_label: __scheme__
              - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
                action: replace
                target_label: __metrics_path__
                regex: (.+)
              - source_labels:
                - __meta_kubernetes_pod_annotation_prometheus_io_port
                - __meta_kubernetes_pod_ip
                action: replace
                regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
                replacement: '[$2]:$1'
                target_label: __address__
              - source_labels:
                - __meta_kubernetes_pod_annotation_prometheus_io_port
                - __meta_kubernetes_pod_ip
                action: replace
                regex: (\d+);((([0-9]+?)(\.|$)){4})
                replacement: $2:$1
                target_label: __address__
              - action: labelmap
                regex: __meta_kubernetes_pod_annotation_prometheus_io_param_(.+)
                replacement: __param_$1
              - action: labelmap
                regex: __meta_kubernetes_pod_label_(.+)
              - source_labels: [__meta_kubernetes_namespace]
                action: replace
                target_label: namespace
              - source_labels: [__meta_kubernetes_pod_name]
                action: replace
                target_label: pod
              - source_labels: [__meta_kubernetes_pod_phase]
                regex: Pending|Succeeded|Failed|Completed
                action: drop
              - source_labels: [__meta_kubernetes_pod_node_name]
                action: replace
                target_label: node
          EOF
        ), var.extra_scrape_configs)
      }
    }
    extraManifests = concat([
      module.minio-user-secret.manifest,
      yamlencode(local.compactor_job),
    ], var.extra_manifests)
  }, var.extra_values)
}

module "minio-user-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-minio-user-secret"
  namespace = var.namespace
  app       = var.name
  release   = "0.1.0"
  data = merge({
    AWS_ACCESS_KEY_ID     = var.minio_user.id
    AWS_SECRET_ACCESS_KEY = var.minio_user.secret
  })
}