output "manifests" {
  value = concat([
    module.secret.manifest,
    module.statefulset.manifest,
    ], [
    for _, m in [
      {
        apiVersion = "policy/v1"
        kind       = "PodDisruptionBudget"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          minAvailable = 1
          selector = {
            matchLabels = {
              app = var.name
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