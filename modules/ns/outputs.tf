output "ignition_snippets" {
  value = concat([
    for f in concat(tolist(fileset(".", "${path.module}/ignition/*.yaml")), [
      "${path.root}/common_templates/ignition/base.yaml",
      "${path.root}/common_templates/ignition/server.yaml",
      "${path.root}/common_templates/ignition/autologin.yaml",
      "${path.root}/common_templates/ignition/masterless_kubelet.yaml",
    ]) :
    templatefile(f, {
      kubelet_config_path = "/var/lib/kubelet"
      pod_mount_path      = "/var/lib/kubelet/podconfig"
      kea_shared_path     = "/var/lib/kea"
      kea_hooks_path      = "/usr/local/lib/kea/hooks"
      kubelet_node_ip     = cidrhost(local.interfaces.lan.prefix, var.netnums.host)
      user                = var.user
      hostname            = var.hostname
      interfaces          = local.interfaces
      container_images    = var.container_images
      netnums             = var.netnums
      upstream_dns        = var.upstream_dns
      internal_dns        = var.internal_dns
      ports               = var.ports
      domains             = var.domains
      kea_peers           = var.kea_peers
      dhcp_server         = var.dhcp_server
    })
    ],
    local.module_ignition_snippets,
  )
}

output "internal_interface_name" {
  value = local.interfaces.internal.interface_name
}