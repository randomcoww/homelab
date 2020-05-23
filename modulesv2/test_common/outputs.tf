output "templates" {
  value = {
    for k in keys(var.test_hosts) :
    k => [
      for template in var.test_templates :
      templatefile(template, {
        hostname                   = k
        user                       = var.user
        container_images           = var.container_images
        domains                    = var.domains
        dns_forward_ip             = "9.9.9.9"
        dns_forward_tls_servername = "dns.quad9.net"

        # Path mounted by kubelet running in container
        kubelet_path = "/var/lib/kubelet"
        # This paths should be visible by kubelet running in the container
        pod_mount_path = "/var/lib/kubelet/podconfig"

        networks     = var.networks
        host_network = var.test_hosts[k].host_network
        host_disks   = var.test_hosts[k].disk
        mtu          = var.mtu
        services     = var.services
      })
    ]
  }
}