locals {
  vlans = {
    for name, vlan in var.vlans :
    name => merge(vlan, try({
      cidr = split("/", vlan.network)[1]
    }, {}))
  }

  # KVM domain interfaces are ens1, ens2 ... ensN in order defined in domain XML
  interface_names = {
    for i, interface in var.domain_interfaces :
    interface.network_name => "ens${i + 1}"
  }

  interfaces = {
    for network_name, interface in var.interfaces :
    network_name => merge(interface, {
      interface_name = local.interface_names[network_name]
      metric         = lookup(interface, "metric", 1024)
      mdns           = lookup(interface, "mdns", false)
      dhcp           = lookup(interface, "dhcp", false)
      mtu            = lookup(interface, "mtu", 1500)
      vrrp_ips = concat(lookup(interface, "vrrp_ips", []), [
        for netnum in lookup(interface, "vrrp_netnums", {}) :
        cidrhost(local.vlans[network_name].network, netnum)
      ])
      }, try({
        network = local.vlans[network_name].network
        ip      = cidrhost(local.vlans[network_name].network, interface.netnum)
        address = join("/", [
          cidrhost(local.vlans[network_name].network, interface.netnum),
          local.vlans[network_name].cidr,
        ])
    }, {}))
  }
}