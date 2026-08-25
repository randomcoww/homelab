output "manifests" {
  value = concat([
    module.secret.manifest,
    ], [
    for _, m in [
      # postgres
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-pg-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-pg-tls"
          secretTemplate = {
            labels = {
              "cnpg.io/reload" = ""
            }
          }
          isCA = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = var.name
          usages = [
            "server auth",
          ]
          dnsNames = [
            "${var.name}-pg-rw",
            "${var.name}-pg-rw.${var.namespace}",
            "${var.name}-pg-r",
            "${var.name}-pg-r.${var.namespace}",
            "${var.name}-pg-ro",
            "${var.name}-pg-ro.${var.namespace}",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-pg-rep-client-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-pg-rep-client-tls"
          secretTemplate = {
            labels = {
              "cnpg.io/reload" = ""
            }
          }
          isCA = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = "streaming_replica" # required user name for replication client
          usages = [
            "client auth",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      {
        apiVersion = "postgresql.cnpg.io/v1"
        kind       = "Cluster"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
        }
        spec = {
          instances = 2
          certificates = {
            serverTLSSecret      = "${var.name}-pg-tls"
            serverCASecret       = "${var.name}-pg-tls"
            clientCASecret       = "${var.name}-pg-rep-client-tls"
            replicationTLSSecret = "${var.name}-pg-rep-client-tls"
          }
          storage = {
            size = "2Gi"
          }
          bootstrap = {
            initdb = {
              database = "authelia"
              owner    = "authelia"
            }
          }
          resources = {
            requests = {
              memory = "128Mi"
            }
            limits = {
              memory = "256Mi"
            }
          }
        }
      },
      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "PodMonitor"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
        }
        spec = {
          selector = {
            matchLabels = {
              "cnpg.io/cluster" = "${var.name}-pg"
            }
          }
          podMetricsEndpoints = [
            {
              port = "metrics"
            },
          ]
        }
      },

      # redis
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-redis-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-redis-tls"
          isCA       = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = "${var.name}-redis"
          usages = [
            "key encipherment",
            "digital signature",
          ]
          dnsNames = [
            "${var.name}-redis.${var.namespace}",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      {
        apiVersion = "dragonflydb.io/v1alpha1"
        kind       = "Dragonfly"
        metadata = {
          name      = "${var.name}-redis"
          namespace = var.namespace
        }
        spec = {
          replicas = 2
          annotations = {
            "secret.reloader.stakater.com/reload" = "${var.name}-redis-tls"
          }
          resources = {
            requests = {
              memory = "128Mi"
            }
          }
          authentication = {
            clientCaCertSecret = {
              name = "${var.name}-redis-tls"
              key  = "ca.crt"
            }
          }
          tlsSecretRef = {
            name      = "${var.name}-redis-tls"
            namespace = var.namespace
          }
        }
      },

      # authelia helm
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "https://charts.authelia.com"
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
              chart   = "authelia"
              version = "0.11.6" # renovate: datasource=helm depName=authelia registryUrl=https://charts.authelia.com
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
          values = local.values
        }
      },

      # ldap client cert
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-ldap-client-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-ldap-client-tls"
          isCA       = false
          privateKey = {
            algorithm = "RSA"
            size      = 4096
          }
          commonName = var.name
          usages = [
            "key encipherment",
            "digital signature",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      # postgres client cert
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-pg-client-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-pg-client-tls"
          isCA       = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = var.name
          usages = [
            "client auth",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      # redis client cert
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-redis-client-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-redis-client-tls"
          isCA       = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = var.name
          usages = [
            "key encipherment",
            "digital signature",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },

      # externalAuth reference grants
      {
        apiVersion = "gateway.networking.k8s.io/v1"
        kind       = "ReferenceGrant"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          from = [
            for _, ns in var.reference_grant_namespaces :
            {
              group     = "gateway.networking.k8s.io"
              kind      = "HTTPRoute"
              namespace = ns
            }
          ]
          to = [
            {
              group = ""
              kind  = "Service"
              name  = var.name
            },
          ]
        }
      },

      # NS
      {
        apiVersion = "v1"
        kind       = "Namespace"
        metadata = {
          name = "kube-amd-gpu"
          annotations = {
            "kustomize.toolkit.fluxcd.io/prune" = "disabled"
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}