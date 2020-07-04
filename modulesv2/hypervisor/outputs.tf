output "matchbox_rpc_endpoints" {
  value = {
    for host, params in var.hosts :
    host => {
      endpoint        = "${params.networks_by_key.main.ip}:${var.services.renderer.ports.rpc}"
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
      endpoint = "qemu+ssh://${var.user}@${params.networks_by_key.main.ip}/system"
    }
  }
}

output "templates" {
  value = {
    for host, params in var.hosts :
    host => [
      for template in var.templates :
      templatefile(template, {
        p                    = params
        user                 = var.user
        container_images     = var.container_images
        services             = var.services
        matchbox_image_path  = "/etc/container-save/matchbox.tar"
        kea_path             = "/var/lib/kea"
        matchbox_tls_path    = "/etc/matchbox/certs"
        matchbox_data_path   = "/etc/matchbox/data"
        matchbox_assets_path = "/etc/matchbox/assets"
        internal_networks    = ["int"]

        tls_matchbox_ca  = replace(tls_self_signed_cert.matchbox-ca.cert_pem, "\n", "\\n")
        tls_matchbox     = replace(tls_locally_signed_cert.matchbox[host].cert_pem, "\n", "\\n")
        tls_matchbox_key = replace(tls_private_key.matchbox[host].private_key_pem, "\n", "\\n")
      })
    ]
  }
}