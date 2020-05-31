output "templates" {
  value = {
    for host, params in var.test_hosts :
    host => [
      for template in var.test_templates :
      templatefile(template, {
        hostname                   = params.hostname
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
        host_network = params.host_network
        host_disks   = params.disk
        mtu          = var.mtu
        services     = var.services
      })
    ]
  }
}