locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version      = var.ignition_version
      fw_mark               = var.fw_mark
      host_netnum           = var.host_netnum
      wan_interface_name    = var.wan_interface_name
      lan_interface_name    = var.lan_interface_name
      lan_gateway_ip        = var.lan_gateway_ip
      keepalived_path       = var.keepalived_path
      bird_path             = var.bird_path
      bird_cache_table_name = var.bird_cache_table_name
      bgp_as                = var.bgp_as
      bgp_port              = var.bgp_port
      bgp_node_prefix       = var.bgp_node_prefix
      bgp_service_prefix    = var.bgp_service_prefix
      bgp_neighbor_netnums  = var.bgp_neighbor_netnums

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