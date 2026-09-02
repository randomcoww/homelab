resource "kubernetes_labels" "labels" {
  for_each = {
    for _, key in keys(lookup(local.members, "kubernetes-worker", {})) :
    key => merge(
      contains(keys(lookup(local.members, "kubernetes-master", {})), key) ? {
        "node-role.kubernetes.io/control-plane" = true
      } : {},
      contains(keys(lookup(local.members, "etcd", {})), key) ? {
        "node-role.kubernetes.io/etcd" = true
      } : {},
      contains(keys(lookup(local.members, "gateway", {})), key) ? {
        "node-role.kubernetes.io/gateway" = true
    } : {})
  }
  api_version = "v1"
  kind        = "Node"
  metadata {
    name = each.key
  }
  labels = each.value
  force  = true
}