output "ignition_snippets" {
  value = concat([
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      kubelet_config_path  = "/var/lib/kubelet"
      pod_mount_path       = "/var/lib/kubelet/podconfig"
      guest_interfaces     = var.guest_interfaces
      netnums              = var.netnums
      master_default_route = var.master_default_route
      slave_default_route  = var.slave_default_route
      container_images     = var.container_images
      upstream_dns         = var.upstream_dns
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
      kubelet_node_ip         = cidrhost(var.guest_interfaces.sync.prefix, var.netnums.host)
      kubelet_container_image = var.container_images.kubelet
    }),
  ])
}