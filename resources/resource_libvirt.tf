module "libvirt-kvm-0" {
  source = "../modules/libvirt"

  domains  = module.template-hypervisor.libvirt_domain.kvm-0
  networks = module.template-hypervisor.libvirt_network.kvm-0
  client   = module.template-hypervisor.libvirt_endpoints.kvm-0
}

module "libvirt-kvm-1" {
  source = "../modules/libvirt"

  domains  = module.template-hypervisor.libvirt_domain.kvm-1
  networks = module.template-hypervisor.libvirt_network.kvm-1
  client   = module.template-hypervisor.libvirt_endpoints.kvm-1
}