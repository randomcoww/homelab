##
## Write config to each libvirt host
## Hardcode each libvirt host until for_each module becomes available
##
module "libvirt-kvm-0" {
  source = "../modulesv2/libvirt"

  endpoint = module.kvm-common.libvirt_endpoints.kvm-0.endpoint
  domains = {
    for h in local.hosts.kvm-0.guests :
    h => module.common-guests.libvirt_domains[h]
    if lookup(module.common-guests.libvirt_domains, h, null) != null
  }
  networks = {
    for n, params in local.hosts.kvm-1.guest_networks :
    n => chomp(templatefile(local.libvirt_networks[n].template, {
      name = n
      pf   = params.pf
    }))
  }
}

module "libvirt-kvm-1" {
  source = "../modulesv2/libvirt"

  endpoint = module.kvm-common.libvirt_endpoints.kvm-1.endpoint
  domains = {
    for h in local.hosts.kvm-1.guests :
    h => module.common-guests.libvirt_domains[h]
    if lookup(module.common-guests.libvirt_domains, h, null) != null
  }
  networks = {
    for n, params in local.hosts.kvm-1.guest_networks :
    n => chomp(templatefile(local.libvirt_networks[n].template, {
      name = n
      pf   = params.pf
    }))
  }
}