output "kvm_params" {
  value = {
    for k in keys(var.kvm_hosts) :
    k => {
      hostname           = k
      user               = var.user
      ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"

      container_images   = var.container_images
      networks           = var.networks
      hosts              = var.kvm_hosts
      mtu                = var.mtu
      networks           = var.networks
      services           = var.services
      certs_path         = "/etc/ssl/certs"
      image_preload_path = "/etc/container-save"

      vlans = [
        for k in keys(var.networks) :
        k
        if lookup(var.networks[k], "id", null) != null
      ]
      internal_networks = {
        int = {
          if = var.networks.int.br_if
          ip = var.services.renderer.vip
        }
      }

      matchbox_data_path       = "/etc/matchbox/data"
      matchbox_assets_path     = "/etc/matchbox/assets"
      tls_matchbox_ca          = replace(tls_self_signed_cert.matchbox-ca.cert_pem, "\n", "\\n")
      tls_matchbox             = replace(tls_locally_signed_cert.matchbox.cert_pem, "\n", "\\n")
      tls_matchbox_key         = replace(tls_private_key.matchbox.private_key_pem, "\n", "\\n")
    }
  }
}

output "matchbox_ca_pem" {
  value = tls_self_signed_cert.matchbox-ca.cert_pem
}

output "matchbox_cert_pem" {
  value = tls_locally_signed_cert.matchbox-client.cert_pem
}

output "matchbox_private_key_pem" {
  value = tls_private_key.matchbox-client.private_key_pem
}

output "matchbox_rpc_endpoints" {
  value = {
    for k in keys(var.kvm_hosts) :
    k => "${var.kvm_hosts[k].host_network.store.ip}:${var.services.renderer.ports.rpc}"
  }
}

output "libvirt_endpoints" {
  value = {
    for k in keys(var.kvm_hosts) :
    k => "qemu+ssh://${var.user}@${var.kvm_hosts[k].host_network.store.ip}/system"
  }
}