output "manifests" {
  value = concat([
    module.secret.manifest,
    module.configmap.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.statefulset.manifest,
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
          issuerRef = {
            name  = "${var.name}-selfsigned"
            kind  = "Issuer"
            group = "cert-manager.io"
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