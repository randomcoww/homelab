##
## Write config to each libvirt host
## Hardcode each libvirt host until for_each module becomes available
##
module "libvirt-kvm-0" {
  source = "../modulesv2/libvirt"

  libvirt_endpoint = module.kvm-common.libvirt_endpoints.kvm-0.endpoint
  libvirt_domains = {
    for h in local.hosts.kvm-0.guests :
    h => module.common-guests.libvirt_domains[h]
    if lookup(module.common-guests.libvirt_domains, h, null) != null
  }
}

module "libvirt-kvm-1" {
  source = "../modulesv2/libvirt"

  libvirt_endpoint = module.kvm-common.libvirt_endpoints.kvm-1.endpoint
  libvirt_domains = {
    for h in local.hosts.kvm-1.guests :
    h => module.common-guests.libvirt_domains[h]
    if lookup(module.common-guests.libvirt_domains, h, null) != null
  }
}