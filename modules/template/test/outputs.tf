locals {
  params = {
    user                       = var.user
    container_images           = var.container_images
    domains                    = var.domains
    dns_forward_ip             = "9.9.9.9"
    dns_forward_tls_servername = "dns.quad9.net"
    services                   = var.services
    kubelet_path               = "/var/lib/kubelet"
    pod_mount_path             = "/var/lib/kubelet/podconfig"
  }
}

output "ignition" {
  value = {
    for host, params in var.hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition/*") :
      templatefile(f, merge(local.params, {
        p = params
      }))
    ]
  }
}