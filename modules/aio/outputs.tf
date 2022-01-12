output "ignition_snippets" {
  value = compact([
    can(var.kea_peers[var.name]) ? templatefile("${path.module}/ignition/kea.yaml", {
      kubelet_config_path      = "/var/lib/kubelet"
      pod_mount_path           = "/var/lib/kubelet/podconfig"
      name                     = var.name
      hostname                 = var.hostname
      dhcp_server              = var.dhcp_server
      kea_shared_path          = var.kea_shared_path
      kea_hooks_libraries_path = var.kea_hooks_libraries_path
      kea_peers                = var.kea_peers
      interfaces               = local.tap_interfaces
      pxeboot_file_name        = var.pxeboot_file_name
      container_images         = var.container_images
      netnums                  = var.netnums
    }) : "",
    templatefile("${path.module}/ignition/hypervisor.yaml", {
      certs = local.certs
    }),
    templatefile("${path.module}/ignition/dns.yaml", {
      kubelet_config_path         = "/var/lib/kubelet"
      pod_mount_path              = "/var/lib/kubelet/podconfig"
      internal_dns_ip             = var.internal_dns_ip
      internal_domain             = var.internal_domain
      upstream_dns_ip             = var.upstream_dns_ip
      upstream_dns_tls_servername = var.upstream_dns_tls_servername
      container_images            = var.container_images
    }),
    templatefile("${path.module}/ignition/network.yaml", {
      networks            = var.networks
      hardware_interfaces = var.hardware_interfaces
      tap_interfaces      = local.tap_interfaces
      netnums             = var.netnums
    }),
    templatefile("${path.module}/ignition/gateway.yaml", {
      interfaces    = local.tap_interfaces
      nftables_name = "gateway_rules"
    }),
    templatefile("${path.module}/ignition/keepalived.yaml", {
      interfaces                  = local.tap_interfaces
      master_default_route        = var.master_default_route
      slave_default_route         = var.slave_default_route
      upstream_dns_ip             = var.upstream_dns_ip
      upstream_dns_tls_servername = var.upstream_dns_tls_servername
      netnums                     = var.netnums
    }),
    templatefile("${path.module}/ignition/conntrackd.yaml", {
      kubelet_config_path = "/var/lib/kubelet"
      pod_mount_path      = "/var/lib/kubelet/podconfig"
      interfaces          = local.tap_interfaces
      container_images    = var.container_images
      netnums             = var.netnums
    }),
    templatefile("${path.root}/common_templates/ignition/base.yaml", {
      users    = [var.user]
      hostname = var.hostname
    }),
    templatefile("${path.root}/common_templates/ignition/server.yaml", {
    }),
    templatefile("${path.root}/common_templates/ignition/masterless_kubelet.yaml", {
      kubelet_config_path     = "/var/lib/kubelet"
      kubelet_node_ip         = cidrhost(local.tap_interfaces.lan.prefix, var.netnums.host)
      kubelet_container_image = var.container_images.kubelet
    }),
    templatefile("${path.root}/common_templates/ignition/container_storage_path.yaml", {
      container_storage_path = var.container_storage_path
    }),
  ])
}

output "interfaces" {
  value = local.tap_interfaces
}