locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      wlan_interface  = var.wlan_interface
      persistent_path = var.persistent_path
    })
  ]
}