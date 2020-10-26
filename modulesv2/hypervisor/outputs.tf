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
      endpoint        = "qemu://${params.networks_by_key.main.ip}/system"
      cert_pem        = tls_locally_signed_cert.libvirt-client.cert_pem
      private_key_pem = tls_private_key.libvirt-client.private_key_pem
      ca_pem          = tls_self_signed_cert.libvirt-ca.cert_pem
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
        libvirt_tls_path     = "/etc/pki"

        tls_matchbox_ca  = replace(tls_self_signed_cert.matchbox-ca.cert_pem, "\n", "\\n")
        tls_matchbox     = replace(tls_locally_signed_cert.matchbox[host].cert_pem, "\n", "\\n")
        tls_matchbox_key = replace(tls_private_key.matchbox[host].private_key_pem, "\n", "\\n")
        tls_libvirt_ca   = replace(tls_self_signed_cert.libvirt-ca.cert_pem, "\n", "\\n")
        tls_libvirt      = replace(tls_locally_signed_cert.libvirt[host].cert_pem, "\n", "\\n")
        tls_libvirt_key  = replace(tls_private_key.libvirt[host].private_key_pem, "\n", "\\n")
      })
    ]
  }
}