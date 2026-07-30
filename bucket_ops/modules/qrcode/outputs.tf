output "manifests" {
  value = concat([
    module.service.manifest,
    module.secret.manifest,
    module.httproute.manifest,
    module.deployment.manifest,
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