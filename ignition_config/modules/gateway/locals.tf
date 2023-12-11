locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      container_images           = var.container_images
      host_netnum                = var.host_netnum
      accept_prefixes            = var.accept_prefixes
      forward_prefixes           = var.forward_prefixes
      conntrackd_ignore_prefixes = var.conntrackd_ignore_prefixes
      wan_interface_name         = var.wan_interface_name
      sync_interface_name        = var.sync_interface_name
      sync_prefix                = var.sync_prefix
      lan_interface_name         = var.lan_interface_name
      lan_prefix                 = var.lan_prefix
      lan_vip                    = var.lan_vip
      static_pod_manifest_path   = var.static_pod_manifest_path
      keepalived_config_path     = var.keepalived_config_path
      dns_port                   = var.dns_port

      nftables_namespace = "gateway"
      virtual_router_id  = 10
      vrrp_master_default_route = {
        table_id       = 250
        table_priority = 32770
      }
      vrrp_slave_default_route = {
        table_id       = 240
        table_priority = 32780
      }
    })
  ]
}