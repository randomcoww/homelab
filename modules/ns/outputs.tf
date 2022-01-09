output "ignition_snippets" {
  value = concat([
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      kubelet_config_path = "/var/lib/kubelet"
      pod_mount_path      = "/var/lib/kubelet/podconfig"
      kea_shared_path     = "/var/lib/kea"
      kea_hooks_path      = "/usr/local/lib/kea/hooks"
      hostname            = var.hostname
      guest_interfaces    = var.guest_interfaces
      container_images    = var.container_images
      netnums             = var.netnums
      upstream_dns        = var.upstream_dns
      internal_dns        = var.internal_dns
      ports               = var.ports
      domains             = var.domains
      kea_peers           = var.kea_peers
      dhcp_server         = var.dhcp_server
    })
    ], [
    templatefile("${path.root}/common_templates/ignition/base.yaml", {
      users    = [var.user]
      hostname = var.hostname
    }),
    templatefile("${path.root}/common_templates/ignition/server.yaml", {
    }),
    templatefile("${path.root}/common_templates/ignition/autologin.yaml", {
      user_name = var.user.name
    }),
    templatefile("${path.root}/common_templates/ignition/masterless_kubelet.yaml", {
      kubelet_config_path     = "/var/lib/kubelet"
      kubelet_node_ip         = cidrhost(var.guest_interfaces.lan.prefix, var.netnums.host)
      kubelet_container_image = var.container_images.kubelet
    }),
  ])
}