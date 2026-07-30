output "manifests" {
  value = concat([
    module.configmap.manifest,
    module.statefulset.manifest,
    module.service.manifest,
    module.service-headless.manifest,
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