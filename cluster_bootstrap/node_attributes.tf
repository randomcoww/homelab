resource "kubernetes_node_taint" "taints" {
  for_each = {
    for key, config in lookup(local.members, "kubernetes-worker", {}) :
    key => config.node_taints if contains(keys(config), "node_taints")
  }

  metadata {
    name = each.key
  }
  dynamic "taint" {
    for_each = each.value
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }
}