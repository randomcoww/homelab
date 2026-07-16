output "manifests" {
  value = concat([
    module.secret.manifest,
    module.statefulset.manifest,
    ], [
    for _, service in module.service-peer :
    service.manifest
    ], [
    for _, m in [
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Issuer"
        metadata = {
          name      = "${var.name}-selfsigned"
          namespace = var.namespace
        }
        spec = {
          selfSigned = {
          }
        }
      },
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-ca-tls"
          namespace = var.namespace
        }
        spec = {
          isCA       = true
          commonName = var.name
          secretName = "${var.name}-ca-tls"
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          issuerRef = {
            name  = "${var.name}-selfsigned"
            kind  = "Issuer"
            group = "cert-manager.io"
          }
        }
      },
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Issuer"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          ca = {
            secretName = "${var.name}-ca-tls"
          }
        }
      },

      # monitoring
      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "PodMonitor"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          selector = {
            matchLabels = {
              app = var.name
            }
          }
          podMetricsEndpoints = [
            {
              path       = "/metrics"
              portNumber = var.ports.kea_metrics
            },
          ]
        }
      },
      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "PrometheusRule"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          groups = [
            {
              name = var.name
              rules = [
                {
                  alert = "KeaDHCP4PoolUsageHigh"
                  expr  = <<-EOF
                  max by (subnet_id) (
                    kea_dhcp4_pool_addresses_assigned_total{job="${var.name}"} /
                    (kea_dhcp4_pool_addresses_total{job="${var.name}"} + 1)
                  ) > 0.90
                  EOF
                  for   = "10m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary     = "Kea DHCPv4 pool usage high"
                    description = "DHCPv4 pool {{ $labels.subnet }} is at {{ $value | humanize }}% utilization."
                  }
                }
              ]
            },
          ]
        }
      },
    ] :
    yamlencode(m)
  ])
}