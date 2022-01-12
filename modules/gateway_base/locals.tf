locals {
  common_ignition_template_path = "${path.root}/common_templates/ignition"

  # assign names for guest interfaces by order
  # libvirt assigns names ens2, ens3 ... ensN in order defined in domain XML
  tap_interfaces = {
    for network_name, tap_interface in var.tap_interfaces :
    network_name => merge(var.networks[network_name], tap_interface, {
      interface_name      = network_name
      vmac_interface_name = "${network_name}-vmac"
    })
  }

  hardware_interfaces = {
    for hardware_interface_name, hardware_interface in var.hardware_interfaces :
    hardware_interface_name => merge(hardware_interface, {
      vlans = {
        for i, network_name in lookup(hardware_interface, "vlans", []) :
        network_name => var.networks[network_name]
      }
    })
  }

  common_ignition_snippets = [
    templatefile("${local.common_ignition_template_path}/base.yaml", {
      users    = [var.user]
      hostname = var.hostname
    }),
    templatefile("${local.common_ignition_template_path}/server.yaml", {}),
    templatefile("${local.common_ignition_template_path}/masterless_kubelet.yaml", {
      kubelet_config_path     = "/var/lib/kubelet/config"
      kubelet_node_ip         = cidrhost(local.tap_interfaces.lan.prefix, var.host_netnum)
      kubelet_container_image = var.container_images.kubelet
    }),
    templatefile("${local.common_ignition_template_path}/container_storage_path.yaml", {
      container_storage_path = var.container_storage_path
    }),
  ]

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      static_pod_manifest_path = "/var/lib/kubelet/manifests"
      static_pod_config_path   = "/var/lib/kubelet/podconfig"
      hostname                 = var.hostname
      interfaces               = local.tap_interfaces
      hardware_interfaces      = local.hardware_interfaces
      host_netnum              = var.host_netnum
      vrrp_netnum              = var.vrrp_netnum

      # gateway #
      nftables_name = "gateway_rules"

      # kea #
      dhcp_server_subnet       = var.dhcp_server_subnet
      kea_shared_path          = "/var/lib/kea"
      kea_hooks_libraries_path = "/usr/local/lib/kea/hooks"
      kea_peers                = var.kea_peers

      # dns #
      internal_dns_ip             = var.internal_dns_ip
      internal_domain             = var.internal_domain
      upstream_dns_ip             = "9.9.9.9"
      upstream_dns_tls_servername = "dns.quad9.net"

      # keepalived #
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