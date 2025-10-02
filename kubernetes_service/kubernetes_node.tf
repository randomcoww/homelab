resource "kubernetes_labels" "labels" {
  for_each = {
    for host_key, host in local.members.kubernetes-worker :
    host_key => lookup(host, "kubernetes_node_labels", {})
  }

  api_version = "v1"
  kind        = "Node"
  metadata {
    name = each.key
  }
  labels = each.value
  force  = true
}