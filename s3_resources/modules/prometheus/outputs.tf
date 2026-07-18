output "manifests" {
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
              chart   = "kube-prometheus-stack"
              version = "87.17.0" # renovate: datasource=helm depName=kube-prometheus-stack registryUrl=https://prometheus-community.github.io/helm-charts
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
          values = local.values
        }
      },

      # certs
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
          ]
          dnsNames = concat([
            var.name,
          ], local.members)
          issuerRef = {
            name = var.name
            kind = "Issuer"
          }
        }
      },
    ] :
    yamlencode(m)
  ]
}