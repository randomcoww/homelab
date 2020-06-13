locals {
  manifests = compact(flatten([
    for k in var.kubernetes_manifests :
    split("---", k)
  ]))
}

resource "kubernetes_manifest" "manifest" {
  provider = kubernetes-alpha
  count    = length(local.manifests)

  manifest = yamldecode(local.manifests[count.index])
}