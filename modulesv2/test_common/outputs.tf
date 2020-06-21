output "templates" {
  value = {
    for host, params in var.hosts :
    host => [
      for template in var.templates :
      templatefile(template, {
        p                          = params
        user                       = var.user
        container_images           = var.container_images
        domains                    = var.domains
        dns_forward_ip             = "9.9.9.9"
        dns_forward_tls_servername = "dns.quad9.net"
        services                   = var.services
        kubelet_path               = "/var/lib/kubelet"
        pod_mount_path             = "/var/lib/kubelet/podconfig"
      })
    ]
  }
}

output "addons" {
  value = {}
}