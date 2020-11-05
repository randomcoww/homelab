resource "kubernetes_manifest" "resource" {
  provider = kubernetes-alpha

  for_each = {
    for k, v in var.kubernetes_manifests :
    k => yamldecode(v)
  }
  manifest = each.value
}