output "manifests" {
  value = concat([
    module.deployment.manifest,
    module.service.manifest,
    module.minio-user-secret.manifest,
    module.configmap.manifest,
    ], [
    for _, m in [
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