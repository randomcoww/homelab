##
## Local resources
##
module "ignition-local" {
  source = "../modulesv2/ignition_local"

  ignition_params = {
    for h in local.local_renderer_hosts_include :
    h => {
      templates = lookup(local.templates_by_host, h, [])
    }
  }
}

resource "local_file" "ignition-local" {
  for_each = module.ignition-local.rendered

  content  = each.value
  filename = "output/ignition/${each.key}.ign"
}

resource "local_file" "kubernetes-addons" {
  for_each = merge(
    module.gateway-common.addons,
    module.kubernetes-common.addons,
    module.ssh-common.addons,
    module.static-pod-logging.addons,
    module.test-common.addons,
  )

  content  = each.value
  filename = "output/addons/${each.key}.yaml"
}