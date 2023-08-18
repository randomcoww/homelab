locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      container_images         = var.container_images
      interfaces               = var.interfaces
      host_netnum              = var.host_netnum
      static_pod_manifest_path = var.static_pod_manifest_path

      # nftables #
      nftables_name      = "gateway"
      pod_network_prefix = var.pod_network_prefix

      # loadbalancer #
      vrrp_master_default_route = {
        table_id       = 250
        table_priority = 32770
      }
      vrrp_slave_default_route = {
        table_id       = 240
        table_priority = 32780
      }
      conntrackd_ipv4_ignore = var.conntrackd_ipv4_ignore
      conntrackd_ipv6_ignore = var.conntrackd_ipv6_ignore
      keepalived_config_path = var.keepalived_config_path
      keepalived_services    = var.keepalived_services
      virtual_router_id      = 10
      upstream_dns           = var.upstream_dns
    })
  ]
}