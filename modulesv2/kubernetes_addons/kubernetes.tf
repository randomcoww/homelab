locals {
  manifests = compact(flatten([
    for k in var.kubernetes_manifests :
    split("---", k)
  ]))

  manifest_keys = {
    for j in local.manifests :
    "${yamldecode(j).kind}-${lookup(yamldecode(j).metadata, "namespace", "default")}-${yamldecode(j).metadata.name}" => j
  }
}

resource "kubernetes_manifest" "manifest" {
  provider = kubernetes-alpha
  for_each = local.manifest_keys

  manifest = yamldecode(each.value)
}