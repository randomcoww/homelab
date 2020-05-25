##
## Write config to each libvirt host
## Hardcode each libvirt host until for_each module becomes available
##
module "libvirt-kvm-0" {
  source = "../modulesv2/libvirt"

  libvirt_endpoint = module.kvm-common.libvirt_endpoints.kvm-0.endpoint
  networks         = local.networks

  guests = {
    for host in local.hosts.kvm-0.guests :
    host => {
      vcpu    = local.hosts[host].vcpu
      memory  = local.hosts[host].memory
      network = lookup(local.hosts[host], "network", [])
      hostdev = lookup(local.hosts[host], "hostdev", [])
      disk = [
        for k in lookup(local.hosts[host], "disk", []) :
        k
        if lookup(k, "source", null) != null && lookup(k, "target", null) != null
      ]
    }
  }
}

module "libvirt-kvm-1" {
  source = "../modulesv2/libvirt"

  libvirt_endpoint = module.kvm-common.libvirt_endpoints.kvm-1.endpoint
  networks         = local.networks

  guests = {
    for host in local.hosts.kvm-1.guests :
    host => {
      vcpu    = local.hosts[host].vcpu
      memory  = local.hosts[host].memory
      network = lookup(local.hosts[host], "network", [])
      hostdev = lookup(local.hosts[host], "hostdev", [])
      disk = [
        for k in lookup(local.hosts[host], "disk", []) :
        k
        if lookup(k, "source", null) != null && lookup(k, "target", null) != null
      ]
    }
  }
}