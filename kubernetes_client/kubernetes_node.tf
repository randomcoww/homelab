resource "kubernetes_labels" "labels" {
  for_each = {
    for key, host in local.members.kubernetes-worker :
    host.hostname => lookup(host, "kubernetes_node_labels", {})
  }

  api_version = "v1"
  kind        = "Node"
  metadata {
    name = each.key
  }
  labels = each.value
  force  = true
}