output "manifests" {
  value = concat([
    module.minio-user-secret.manifest,
    ], [
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
          url      = "http://zotregistry.dev/helm-charts"
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
              chart   = "zot"
              version = "0.1.122" # renovate: datasource=helm depName=zot registryUrl=http://zotregistry.dev/helm-charts
              sourceRef = {
                kind = "HelmRepository"
                name = var.name
              }
              interval = "5m"
            }
          }
          releaseName = var.name
          install = {
            createNamespace = true
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
            replicaCount = 2
            service = {
              type = "LoadBalancer"
              port = var.service_port
              annotations = {
                "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
                "lbipam.cilium.io/ips"                      = var.service_ip
              }
            }
            ingress = {
              enabled = false
            }
            httproute = {
              enabled = false
            }
            listenerset = {
              enabled = false
            }
            httpGet = {
              scheme = "HTTPS"
              port   = var.service_port
            }
            mountConfig = true
            mountSecret = false
            externalSecrets = [
              {
                secretName = "${var.name}-tls"
                mountPath  = local.tls_path
              },
            ]
            configFiles = {
              "config.json" = jsonencode({
                http = {
                  address = "0.0.0.0"
                  port    = var.service_port
                  tls = {
                    cert   = "${local.tls_path}/tls.crt"
                    key    = "${local.tls_path}/tls.key"
                    cacert = "${local.tls_path}/ca.crt"
                  }
                  auth = {
                    mtls = {
                      identityAttributes = [
                        "CommonName",
                      ]
                    }
                  }
                  accessControl = {
                    groups = {
                      machines = {
                        users = [
                          "gha",
                          "worker",
                        ]
                      }
                    }
                    repositories = {
                      "**" = {
                        policies = [
                          {
                            groups  = ["machines"]
                            actions = ["read", "create", "update", "delete"]
                          },
                        ],
                        defaultPolicy = ["read"]
                      }
                    },
                    metrics = {
                      anonymousPolicy = ["read"]
                    }
                  }
                }
                storage = {
                  rootDirectory = "/var/tmp/zot"
                  dedupe        = false
                  remoteCache   = false
                  storageDriver = {
                    name           = "s3"
                    region         = "us-east-2" # placeholder
                    regionendpoint = var.minio_endpoint
                    forcepathstyle = true
                    bucket         = var.name
                    secure         = true
                    skipverify     = false
                  }
                }
                log = {
                  level = "info"
                }
                extensions = {
                  metrics = {
                    enable = true
                    prometheus = {
                      path = "/metrics"
                    }
                  }
                }
              })
            }
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
              {
                name  = "SSL_CERT_FILE"
                value = "/etc/ssl/certs/ca-certificates.crt"
              },
            ]
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
            metrics = {
              enabled = true
              serviceMonitor = {
                enabled   = true
                scheme    = "https"
                basicAuth = null
              }
            }
          }
        }
      },

      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-tls"
          isCA       = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = var.name
          usages = [
            "key encipherment",
            "digital signature",
            "server auth",
          ]
          ipAddresses = [
            "127.0.0.1",
            var.service_ip,
          ]
          dnsNames = [
            var.name,
            "${var.name}.${var.namespace}",
            var.service_hostname,
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },

      # static service IP
      {
        apiVersion = "cilium.io/v2"
        kind       = "CiliumLoadBalancerIPPool"
        metadata = {
          name = "${var.namespace}-${var.name}"
        }
        spec = {
          blocks = [
            {
              cidr = "${var.service_ip}/32"
            },
          ]
          serviceSelector = {
            matchLabels = {
              "io.kubernetes.service.namespace" = var.namespace
              "io.kubernetes.service.name"      = var.name
            }
          }
        }
      },

      # NS
      {
        apiVersion = "v1"
        kind       = "Namespace"
        metadata = {
          name = var.namespace
          annotations = {
            "kustomize.toolkit.fluxcd.io/prune" = "disabled"
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}