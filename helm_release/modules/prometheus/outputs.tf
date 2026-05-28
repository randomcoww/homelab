output "name" {
  value = var.name
}

output "kustomize" {
  value = {
    "release.yaml" = join("---\n", local.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      namespace  = var.namespace
      resources = [
        "release.yaml",
      ]
    })
  }
}