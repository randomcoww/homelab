output "manifests" {
  value = concat([
    module.deployment.manifest,
    module.service.manifest,
    module.minio-user-secret.manifest,
    module.configmap.manifest,
    ], [
    for _, m in [
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
            "server auth",
          ]
          ipAddresses = [
            "127.0.0.1",
            var.service_ip,
          ]
          dnsNames = [
            var.name,
            "${var.name}.${var.namespace}",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },

      # static service IP when using cilium
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