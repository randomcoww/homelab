locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      sync_interface_name    = var.sync_interface_name
      mdns_interface_name    = var.mdns_interface_name
      mdns_resolver_vip      = var.mdns_resolver_vip
      keepalived_config_path = var.keepalived_config_path
      virtual_router_id      = 12
    })
  ]
}