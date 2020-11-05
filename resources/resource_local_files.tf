##
## Local resources
##
module "ignition-local" {
  source = "../modules/ignition_local"

  ignition_params = {
    for host in local.local_renderer_hosts_include :
    host => {
      templates = lookup(local.ignition_by_host, host, [])
    }
  }
}

resource "local_file" "ignition" {
  for_each = module.ignition-local.rendered

  content  = each.value
  filename = "output/ignition/${each.key}.ign"
}

resource "local_file" "kubernetes-local" {
  content = join("\n---\n", concat([
    for j in local.kubernetes_addons_local :
    yamlencode(j) if lookup(j, "kind", null) == "Namespace"
    ], [
    for j in local.kubernetes_addons_local :
    yamlencode(j) if lookup(j, "kind", "Namespace") != "Namespace"
  ]))
  filename = "output/kubernetes/addons.yaml"
}