##
## Write config to each matchbox host
## Hardcode each matchbox host until for_each module becomes available
##
# module "ignition-hypervisor" {
#   source = "../modulesv2/ignition_pxe"
#   for_each = module.hypervisor.matchbox_rpc_endpoints

#   ignition_params = merge([
#     for params in values(local.aggr_hosts[each.key].libvirt_domains) :
#     {
#       for h in params.nodes :
#       h => {
#         templates = lookup(local.templates_by_host, h, [])
#         selector  = lookup(local.aggr_hosts[h].networks_by_key, "int", {})
#       }
#     }]...
#   )

#   services      = local.services
#   renderer      = each.value
#   kernel_image  = local.kernel_image
#   initrd_images = local.initrd_images
#   kernel_params = local.kernel_params
# }

module "ignition-kvm-0" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = merge([
    for params in values(local.aggr_hosts.kvm-0.libvirt_domains) :
    {
      for h in params.nodes :
      h => {
        templates = lookup(local.templates_by_host, h, [])
        selector  = lookup(local.aggr_hosts[h].networks_by_key, "int", {})
      }
    }]...
  )

  services      = local.services
  renderer      = module.hypervisor.matchbox_rpc_endpoints.kvm-0
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

module "ignition-kvm-1" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = merge([
    for params in values(local.aggr_hosts.kvm-1.libvirt_domains) :
    {
      for h in params.nodes :
      h => {
        templates = lookup(local.templates_by_host, h, [])
        selector  = lookup(local.aggr_hosts[h].networks_by_key, "int", {})
      }
    }]...
  )

  services      = local.services
  renderer      = module.hypervisor.matchbox_rpc_endpoints.kvm-1
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

module "ignition-desktop" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = merge([
    for params in values(local.aggr_hosts.desktop.libvirt_domains) :
    {
      for h in params.nodes :
      h => {
        templates = lookup(local.templates_by_host, h, [])
        selector  = lookup(local.aggr_hosts[h].networks_by_key, "int", {})
      }
    }]...
  )

  services      = local.services
  renderer      = module.hypervisor.matchbox_rpc_endpoints.desktop
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

##
## Local renderer
##
module "ignition-local" {
  source = "../modulesv2/ignition_local"

  ignition_params = {
    for h in local.local_renderer_hosts_include :
    h => {
      templates = lookup(local.templates_by_host, h, [])
    }
  }

  renderer = local.local_renderer
}

module "generic-manifest-local" {
  source = "../modulesv2/generic_manifest"

  generic_params = data.null_data_source.render-addons.outputs
  renderer       = local.local_renderer
}