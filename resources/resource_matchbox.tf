locals {
  pxeboot_params = {
    for host, params in local.aggr_hosts :
    host => {
      for g in params.libvirt_domains :
      g.node => {
        templates     = local.ignition_by_host[g.node]
        kernel_image  = params.kernel_image
        initrd_images = params.initrd_images
        kernel_params = g.host.kernel_params
        selector      = g.host.metadata
      }
    }
  }
}

module "ignition-kvm-0" {
  source = "../modules/ignition_pxe"

  services        = local.services
  ignition_params = local.pxeboot_params.kvm-0
  renderer        = module.template-hypervisor.matchbox_rpc_endpoints.kvm-0
}

module "ignition-kvm-1" {
  source = "../modules/ignition_pxe"

  services        = local.services
  ignition_params = local.pxeboot_params.kvm-1
  renderer        = module.template-hypervisor.matchbox_rpc_endpoints.kvm-1
}