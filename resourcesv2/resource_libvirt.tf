##
## Write config to each libvirt host
## Hardcode each libvirt host until for_each module becomes available
##
module "libvirt-kvm-0" {
  source = "../modulesv2/libvirt"

  libvirt_endpoint = local.libvirt.kvm-0.endpoint
  networks         = local.networks

  guests = {
    for k in local.hosts.kvm-0.guests :
    k => {
      vcpu    = local.hosts[k].vcpu
      memory  = local.hosts[k].memory
      network = lookup(local.hosts[k], "network", [])
      hostdev = lookup(local.hosts[k], "hostdev", [])
      disk = [
        for k in lookup(local.hosts[k], "disk", []) :
        k
        if lookup(k, "source", null) != null && lookup(k, "target", null) != null
      ]
    }
  }
}

module "libvirt-kvm-1" {
  source = "../modulesv2/libvirt"

  libvirt_endpoint = local.libvirt.kvm-1.endpoint
  networks         = local.networks

  guests = {
    for k in local.hosts.kvm-1.guests :
    k => {
      vcpu    = local.hosts[k].vcpu
      memory  = local.hosts[k].memory
      network = lookup(local.hosts[k], "network", [])
      hostdev = lookup(local.hosts[k], "hostdev", [])
      disk = [
        for k in lookup(local.hosts[k], "disk", []) :
        k
        if lookup(k, "source", null) != null && lookup(k, "target", null) != null
      ]
    }
  }
}

module "libvirt-desktop-0" {
  source = "../modulesv2/libvirt"

  libvirt_endpoint = local.libvirt.desktop-0.endpoint
  networks         = local.networks

  guests = {
    for k in local.hosts.desktop-0.guests :
    k => {
      vcpu    = local.hosts[k].vcpu
      memory  = local.hosts[k].memory
      network = lookup(local.hosts[k], "network", [])
      hostdev = lookup(local.hosts[k], "hostdev", [])
      disk = [
        for k in lookup(local.hosts[k], "disk", []) :
        k
        if lookup(k, "source", null) != null && lookup(k, "target", null) != null
      ]
    }
  }
}