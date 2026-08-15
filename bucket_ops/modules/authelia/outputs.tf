output "manifests" {
  value = concat([
    module.secret.manifest,
    ], [
    for _, m in [
      # database
      {
        apiVersion = "postgresql.cnpg.io/v1"
        kind       = "Cluster"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
        }
        spec = {
          instances = 3
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
    ] :
    yamlencode(m)
  ])
}