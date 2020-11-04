locals {
  pxeboot_params = {
    for host, params in local.aggr_hosts :
    host => {
      for guest in host.libvirt_domains :
      guest => {
        templates     = var.ignition_by_host[guest]
        selector      = host.kernel_image
        kernel_image  = host.kernel_image
        initrd_images = host.initrd_images
        kernel_params = guest.kernel_params
      }
    }
  }
}

module "ignition-kvm-0" {
  source = "../modules/ignition_pxe"

  services        = local.services
  ignition_params = local.pxeboot_params.kvm-0
  renderer        = module.hypervisor.matchbox_rpc_endpoints.kvm-0
}

module "ignition-kvm-1" {
  source = "../modules/ignition_pxe"

  services        = local.services
  ignition_params = local.pxeboot_params.kvm-1
  renderer        = module.hypervisor.matchbox_rpc_endpoints.kvm-1
}