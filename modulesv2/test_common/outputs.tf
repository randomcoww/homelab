output "test_params" {
  value = {
    for k in keys(var.test_hosts) :
    k => {
      hostname           = k
      user               = var.user
      ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"

      networks     = var.networks
      host_network = var.test_hosts[k].host_network
      mtu          = var.mtu
      services     = var.services
    }
  }
}