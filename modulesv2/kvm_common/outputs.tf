output "matchbox_rpc_endpoints" {
  value = {
    for host, params in var.hosts :
    host => {
      endpoint        = "${params.host_network.main.ip}:${var.services.renderer.ports.rpc}"
      cert_pem        = tls_locally_signed_cert.matchbox-client.cert_pem
      private_key_pem = tls_private_key.matchbox-client.private_key_pem
      ca_pem          = tls_self_signed_cert.matchbox-ca.cert_pem
    }
  }
}

output "libvirt_endpoints" {
  value = {
    for host, params in var.hosts :
    host => {
      endpoint = "qemu+ssh://${var.user}@${params.host_network.main.ip}/system"
    }
  }
}

output "templates" {
  value = {
    for host, params in var.hosts :
    host => [
      for template in var.templates :
      templatefile(template, {
        hostname             = params.hostname
        user                 = var.user
        container_images     = var.container_images
        networks             = var.networks
        host_network         = params.host_network
        mtu                  = var.mtu
        networks             = var.networks
        domains              = var.domains
        services             = var.services
        matchbox_image_path  = "/etc/container-save/matchbox.tar"
        image_device         = params.image_device
        kea_path             = "/var/lib/kea"
        matchbox_tls_path    = "/etc/matchbox/certs"
        matchbox_data_path   = "/etc/matchbox/data"
        matchbox_assets_path = "/etc/matchbox/assets"

        vlans = [
          for k, v in var.networks :
          k
          if lookup(v, "id", null) != null
        ]
        internal_networks = {
          int = {
            if = var.networks.int.br_if
            ip = var.services.renderer.vip
          }
        }

        tls_matchbox_ca  = replace(tls_self_signed_cert.matchbox-ca.cert_pem, "\n", "\\n")
        tls_matchbox     = replace(tls_locally_signed_cert.matchbox[host].cert_pem, "\n", "\\n")
        tls_matchbox_key = replace(tls_private_key.matchbox[host].private_key_pem, "\n", "\\n")
      })
    ]
  }
}