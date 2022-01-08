output "ignition_snippets" {
  value = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      interfaces  = local.interfaces
      host_netnum = var.host_netnum
    })
  ]
}

output "guest_interface_device_order" {
  value = local.guest_interface_device_order
}

output "interfaces" {
  value = local.interfaces
}