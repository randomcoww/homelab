module "libvirt-kvm-0" {
  source = "../modules/libvirt"

  domains  = module.hypervisor.libvirt_domain.kvm-0
  networks = module.hypervisor.libvirt_network.kvm-0
  client   = module.hypervisor.libvirt_endpoints.kvm-0
}

module "libvirt-kvm-1" {
  source = "../modules/libvirt"

  domains  = module.hypervisor.libvirt_domain.kvm-1
  networks = module.hypervisor.libvirt_network.kvm-1
  client   = module.hypervisor.libvirt_endpoints.kvm-1
}