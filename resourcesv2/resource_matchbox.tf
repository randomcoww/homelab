module "ignition-kvm-0" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = {
    for v in local.aggr_libvirt_domains.kvm-0 :
    v.node => {
      templates     = lookup(local.templates_by_host, v.node, [])
      selector      = v.metadata
      kernel_image  = v.kernel_image
      initrd_images = v.initrd_images
      kernel_params = v.kernel_params
    }
  }

  services = local.services
  renderer = module.hypervisor.matchbox_rpc_endpoints.kvm-0
}

module "ignition-kvm-1" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = {
    for v in local.aggr_libvirt_domains.kvm-1 :
    v.node => {
      templates     = lookup(local.templates_by_host, v.node, [])
      selector      = v.metadata
      kernel_image  = v.kernel_image
      initrd_images = v.initrd_images
      kernel_params = v.kernel_params
    }
  }

  services = local.services
  renderer = module.hypervisor.matchbox_rpc_endpoints.kvm-1
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