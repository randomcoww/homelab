locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version              = var.ignition_version
      fw_mark                       = var.fw_mark
      host_netnum                   = var.host_netnum
      conntrackd_ignore_prefixes    = var.conntrackd_ignore_prefixes
      wan_interface_name            = var.wan_interface_name
      sync_interface_name           = var.sync_interface_name
      lan_interface_name            = var.lan_interface_name
      sync_prefix                   = var.sync_prefix
      lan_prefix                    = var.lan_prefix
      lan_gateway_ip                = var.lan_gateway_ip
      keepalived_path               = var.keepalived_path
      bird_path                     = var.bird_path
      bird_cache_table_name         = var.bird_cache_table_name
      bgp_prefix                    = var.bgp_prefix
      bgp_as                        = var.bgp_as
      bgp_port                      = var.bgp_port
      bgp_external_neighbor_netnums = var.bgp_external_neighbor_netnums
      bgp_internal_neighbor_netnums = var.bgp_internal_neighbor_netnums

      virtual_router_id = var.virtual_router_id
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