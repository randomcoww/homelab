output "manifests" {
  value = concat([
    module.secret.manifest,
    module.statefulset.manifest,
    ], [
    for _, m in [
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