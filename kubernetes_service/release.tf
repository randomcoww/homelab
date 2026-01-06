## Hack to release custom charts as local chart

locals {
  modules_enabled = [
    module.bootstrap,
    module.kube-proxy,
    module.flannel,
    module.kube-vip,
    module.device-plugin,
    module.kea,
    module.lldap,
    module.tailscale,
    module.hostapd,
    module.qrcode-hostapd,
    module.kavita,
    module.registry,
    module.searxng,
    module.mcp-proxy,
    module.open-webui,
    module.llama-cpp,
    module.sunshine-desktop,
  ]
}

# Node labels

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

# All modules

resource "helm_release" "wrapper" {
  for_each = {
    for m in local.modules_enabled :
    m.chart.name => m.chart
  }
  chart            = "../helm-wrapper"
  name             = each.key
  namespace        = each.value.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      manifests = values(each.value.manifests)
    }),
  ]
}