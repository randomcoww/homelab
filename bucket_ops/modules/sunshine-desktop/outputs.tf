output "manifests" {
  value = concat([
    module.secret.manifest,
    module.configmap.manifest,
    module.service.manifest,
    module.admin-service.manifest,
    module.httproute.manifest,
    module.statefulset.manifest,
    ], [
    for _, m in [
      # server cert
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
            algorithm = "RSA"
            size      = 4096
          }
          dnsNames = [
            "${var.name}.${var.namespace}",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      {
        apiVersion = "gateway.networking.k8s.io/v1"
        kind       = "BackendTLSPolicy"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          targetRefs = [
            {
              group = ""
              kind  = "Service"
              name  = module.admin-service.name
            },
          ]
          validation = {
            hostname = "${var.name}.${var.namespace}"
            caCertificateRefs = [
              {
                /*
                TODO: migrate to ClusterTrustBundle
                GEP-5075 mentioned here https://github.com/cilium/cilium/issues/47759

                group = "certificates.k8s.io"
                kind  = "ClusterTrustBundle"
                name  = "trust-bundle-ca-internal"
                */
                group = ""
                kind  = "ConfigMap"
                name  = "trust-manager-ca-internal"
              },
            ]
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
      }
    ] :
    yamlencode(m)
  ])
}