resource "kubernetes_labels" "labels" {
  for_each = local.node_labels

  api_version = "v1"
  kind        = "Node"
  metadata {
    name = each.key
  }
  labels = each.value
}

resource "kubernetes_node_taint" "taint" {
  for_each = local.node_taints

  metadata {
    name = each.key
  }
  taint {
    key    = each.value.key
    value  = lookup(each.value, "value", "")
    effect = each.value.effect
  }
}