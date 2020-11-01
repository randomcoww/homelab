resource "kubernetes_manifest" "manifest" {
  provider = kubernetes-alpha
  for_each = {
    for j in compact(flatten([
      for k in var.kubernetes_manifests :
      split("---", k)
    ])) :
    "${yamldecode(j).kind}-${lookup(yamldecode(j).metadata, "namespace", "default")}-${yamldecode(j).metadata.name}" => j
  }

  manifest = yamldecode(each.value)
}