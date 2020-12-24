## PXE boot entries
module "ignition-kvm-0" {
  source = "../modules/ignition"

  services        = local.services
  ignition_params = local.pxeboot_by_host.kvm-0
  renderer        = module.template-hypervisor.matchbox_rpc_endpoints.kvm-0
}

module "ignition-kvm-2" {
  source = "../modules/ignition"

  services        = local.services
  ignition_params = local.pxeboot_by_host.kvm-2
  renderer        = module.template-hypervisor.matchbox_rpc_endpoints.kvm-2
}

module "ignition-client-0" {
  source = "../modules/ignition"

  services        = local.services
  ignition_params = local.pxeboot_by_host.client-0
  renderer        = module.template-hypervisor.matchbox_rpc_endpoints.client-0
}

## Libvirt config
module "libvirt-kvm-0" {
  source = "../modules/libvirt"

  domains  = module.template-hypervisor.libvirt_domain.kvm-0
  networks = module.template-hypervisor.libvirt_network.kvm-0
  client   = module.template-hypervisor.libvirt_endpoints.kvm-0
}

module "libvirt-kvm-2" {
  source = "../modules/libvirt"

  domains  = module.template-hypervisor.libvirt_domain.kvm-2
  networks = module.template-hypervisor.libvirt_network.kvm-2
  client   = module.template-hypervisor.libvirt_endpoints.kvm-2
}

module "libvirt-client-0" {
  source = "../modules/libvirt"

  domains  = module.template-hypervisor.libvirt_domain.client-0
  networks = module.template-hypervisor.libvirt_network.client-0
  client   = module.template-hypervisor.libvirt_endpoints.client-0
}