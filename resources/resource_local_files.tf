##
## Local resources
##
module "ignition-local" {
  source = "../modules/ignition_local"

  ignition_params = {
    for host in local.local_renderer_hosts_include :
    host => {
      templates = lookup(local.templates_by_host, h, [])
    }
  }
}

resource "local_file" "ignition" {
  for_each = module.ignition-local.rendered

  content  = each.value
  filename = "output/ignition/${each.key}.ign"
}

resource "local_file" "kubernetes" {
  content = join("\n---\n", [
    module.template-gateway.kubernetes,
    module.template-static-pod-logging.kubernetes,
  ])
  filename = "output/kubernetes/addons.yaml"
}