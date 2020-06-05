##
## Write config to each matchbox host
## Hardcode each matchbox host until for_each module becomes available
##
module "ignition-kvm-0" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = {
    for h in local.hosts.kvm-0.guests :
    h => {
      templates = flatten([
        lookup(module.kubernetes-common.templates, h, []),
        lookup(module.gateway-common.templates, h, []),
        lookup(module.test-common.templates, h, []),
        lookup(module.ssh-common.templates, h, []),
        lookup(module.secrets.templates, h, []),
      ])
      selector = lookup(local.host_network_by_type[h], "int", {})
    }
  }

  services      = local.services
  renderer      = module.kvm-common.matchbox_rpc_endpoints.kvm-0
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

module "ignition-kvm-1" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = {
    for h in local.hosts.kvm-1.guests :
    h => {
      templates = flatten([
        lookup(module.kubernetes-common.templates, h, []),
        lookup(module.gateway-common.templates, h, []),
        lookup(module.test-common.templates, h, []),
        lookup(module.ssh-common.templates, h, []),
        lookup(module.secrets.templates, h, []),
      ])
      selector = lookup(local.host_network_by_type[h], "int", {})
    }
  }

  services      = local.services
  renderer      = module.kvm-common.matchbox_rpc_endpoints.kvm-1
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

# Build and test environment
module "ignition-local" {
  source = "../modulesv2/ignition_local"

  ignition_params = {
    for h in local.local_renderer_hosts_include :
    h => {
      templates = flatten([
        lookup(module.kvm-common.templates, h, []),
        lookup(module.desktop-common.templates, h, []),
        lookup(module.ssh-common.templates, h, []),
        lookup(module.secrets.templates, h, []),
      ])
    }
  }

  renderer = local.local_renderer
}

module "generic-manifest-local" {
  source = "../modulesv2/generic_manifest"

  generic_params = merge(
    module.gateway-common.addons,
    module.kubernetes-common.addons,
    module.secrets.addons,
    module.ssh-common.addons,
    module.test-common.addons,
  )

  renderer = local.local_renderer
}