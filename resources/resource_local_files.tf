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