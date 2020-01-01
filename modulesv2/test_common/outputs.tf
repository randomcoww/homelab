output "test_params" {
  value = {
    for k in keys(var.test_hosts) :
    k => {
      hostname           = k
      user               = var.user
      ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"

      container_images = var.container_images
      domains          = var.domains

      # Path mounted by kubelet running in container
      kubelet_path = "/var/lib/kubelet"
      # This paths should be visible by kubelet running in the container
      pod_mount_path = "/var/lib/kubelet/podconfig"

      networks     = var.networks
      host_network = var.test_hosts[k].host_network
      mtu          = var.mtu
      services     = var.services
    }
  }
}