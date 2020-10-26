module "libvirt-kvm-0" {
  source = "../modulesv2/libvirt"

  client = module.hypervisor.libvirt_endpoints.kvm-0
  domains = {
    for v in local.aggr_libvirt_domains.kvm-0 :
    v.node => chomp(templatefile(v.libvirt_domain_template, {
      p      = v
      host_p = local.aggr_hosts.kvm-0
    }))
  }
  networks = {
    for v in local.aggr_hosts.kvm-0.hwif :
    v.label => chomp(templatefile(local.aggr_hosts.kvm-0.libvirt_network_template, v))
  }
}

module "libvirt-kvm-1" {
  source = "../modulesv2/libvirt"

  client = module.hypervisor.libvirt_endpoints.kvm-1
  domains = {
    for v in local.aggr_libvirt_domains.kvm-1 :
    v.node => chomp(templatefile(v.libvirt_domain_template, {
      p      = v
      host_p = local.aggr_hosts.kvm-0
    }))
  }
  networks = {
    for v in local.aggr_hosts.kvm-1.hwif :
    v.label => chomp(templatefile(local.aggr_hosts.kvm-0.libvirt_network_template, v))
  }
}