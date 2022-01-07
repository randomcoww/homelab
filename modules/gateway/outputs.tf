output "ignition_snippets" {
  value = [
    for f in concat(tolist(fileset(".", "${path.module}/ignition/*.yaml")), [
      "${path.root}/common_templates/ignition/base.yaml",
      "${path.root}/common_templates/ignition/server.yaml",
      "${path.root}/common_templates/ignition/vm.yaml",
      "${path.root}/common_templates/ignition/masterless_kubelet.yaml",
    ]) :
    templatefile(f, {
      kubelet_config_path  = "/var/lib/kubelet"
      pod_mount_path       = "/var/lib/kubelet/podconfig"
      kubelet_node_ip      = cidrhost(local.interfaces.sync.prefix, var.netnums.host)
      user                 = var.user
      hostname             = var.hostname
      interfaces           = local.interfaces
      internal_interface   = local.internal_interface
      netnums              = var.netnums
      master_default_route = var.master_default_route
      slave_default_route  = var.slave_default_route
      container_images     = var.container_images
      upstream_dns         = var.upstream_dns
    })
  ]
}

output "libvirt" {
  value = templatefile("${path.root}/common_templates/libvirt/domain.xml", {
    name               = var.hostname
    memory             = 512
    vcpu               = 1
    domain_interfaces  = var.domain_interfaces
    hypervisor_devices = var.hypervisor_devices
  })
}