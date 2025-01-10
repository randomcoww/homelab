locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version          = var.ignition_version
      fw_mark                   = var.fw_mark
      host_netnum               = var.host_netnum
      wan_interface_name        = var.wan_interface_name
      bird_path                 = var.bird_path
      bird_cache_table_name     = var.bird_cache_table_name
      bgp_as                    = var.bgp_as
      bgp_port                  = var.bgp_port
      bgp_node_prefix           = var.bgp_node_prefix
      bgp_service_prefix        = var.bgp_service_prefix
      bgp_neighbor_netnums      = var.bgp_neighbor_netnums
      sync_interface_name       = var.sync_interface_name
      conntrackd_ip             = var.conntrackd_ip
      conntrackd_ignore_ipv4    = var.conntrackd_ignore_ipv4
      keepalived_path           = var.keepalived_path
      keepalived_interface_name = var.keepalived_interface_name
      keepalived_vip            = var.keepalived_vip
      keepalived_router_id      = var.keepalived_router_id
      keepalived_prefix         = var.keepalived_prefix

      master_default_route = {
        table_id       = 250
        table_priority = 32770
      }
      slave_default_route = {
        table_id       = 240
        table_priority = 32780
      }
    })
  ]
}