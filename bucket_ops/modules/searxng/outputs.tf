output "manifests" {
  value = concat([
    module.deployment.manifest,
    module.secret.manifest,
    module.service.manifest,
    ], [
    for _, m in [
      {
        # NS
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