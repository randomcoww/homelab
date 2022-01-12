
output "ignition_snippets" {
  value = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      certs = local.certs.libvirt
    })
  ]
}

output "libvirt_endpoints" {
  value = {
    for network_name, network in var.networks :
    network_name => concat([
      for interface in values(var.interfaces) :
      "qemu://${cidrhost(interface.prefix, var.netnums.host)}/system"
      if lookup(interface, "enable_netnum", false)
    ])
  }
}