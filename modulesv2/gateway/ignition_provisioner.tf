##
## provisioner ignition renderer
##
resource "matchbox_profile" "ign-gateway" {
  name                   = "gateway"
  container_linux_config = "{{.config}}"
}

resource "matchbox_group" "ign-gateway" {
  for_each = var.gateway_hosts

  profile = matchbox_profile.ign-gateway.name
  name    = each.key
  selector = {
    ign = each.key
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/ignition/gateway.ign.tmpl", {
      hostname           = each.key
      user               = var.user
      ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"

      container_images = var.container_images
      networks         = var.networks
      host_network     = each.value.network
      services         = var.services
      domains          = var.domains
      mtu              = var.mtu

      dns_forward = {
        ip          = "9.9.9.9"
        server_name = "dns.quad9.net"
      }

      kubelet_path = "/var/lib/kubelet"
      kea_path     = "/var/lib/kea"
      kea_ha_peers = jsonencode([
        for k in keys(var.gateway_hosts) :
        {
          name = k
          role = var.gateway_hosts[k].kea_ha_role
          url  = "http://${var.gateway_hosts[k].network.sync_ip}:${var.services.kea.ports.peer}/"
        }
      ])
    })
  }
}