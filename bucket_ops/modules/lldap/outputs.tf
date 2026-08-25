output "manifests" {
  value = concat([
    module.deployment.manifest,
    module.service.manifest,
    module.httproute.manifest,
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
            algorithm = "RSA"
            size      = 4096
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
            algorithm = "RSA"
            size      = 4096
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
              database = "lldap"
              owner    = "lldap"
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

      # lldap pg client
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
            algorithm = "RSA"
            size      = 4096
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

      # lldap server
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
            algorithm = "RSA"
            size      = 4096
          }
          commonName = var.name
          usages = [
            "key encipherment",
            "digital signature",
          ]
          ipAddresses = [
            "127.0.0.1",
          ]
          dnsNames = [
            var.name,
            "${var.name}.${var.namespace}.svc.${var.service_domain}",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
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