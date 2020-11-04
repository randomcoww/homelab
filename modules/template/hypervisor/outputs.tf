locals {
  params = {
    user                 = var.user
    container_images     = var.container_images
    services             = var.services
    matchbox_image_path  = "/etc/container-save/matchbox.tar"
    kea_path             = "/var/lib/kea"
    matchbox_tls_path    = "/etc/matchbox/certs"
    matchbox_data_path   = "/etc/matchbox/data"
    matchbox_assets_path = "/etc/matchbox/assets"
    libvirt_tls_path     = "/etc/pki"
  }
}

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

output "ignition" {
  value = {
    for host, params in var.hosts :
    host => [
      for f in fileset("templates/ignition", "*") :
      templatefile(f, merge(local.params, {
        p                    = params
        tls_matchbox_ca  = replace(tls_self_signed_cert.matchbox-ca.cert_pem, "\n", "\\n")
        tls_matchbox     = replace(tls_locally_signed_cert.matchbox[host].cert_pem, "\n", "\\n")
        tls_matchbox_key = replace(tls_private_key.matchbox[host].private_key_pem, "\n", "\\n")
        tls_libvirt_ca   = replace(tls_self_signed_cert.libvirt-ca.cert_pem, "\n", "\\n")
        tls_libvirt      = replace(tls_locally_signed_cert.libvirt[host].cert_pem, "\n", "\\n")
        tls_libvirt_key  = replace(tls_private_key.libvirt[host].private_key_pem, "\n", "\\n")
      }))
    ]
  }
}

output "libvirt_domain" {
  value = {
    for host, params in var.hosts :
    host => [
      for guest in host.libvirt_domains :
      chomp(templatefile("templates/libvirt_domain.xml.tmpl", {
        p = params
        g = guest
      }))
    ]
  }
}

output "libvirt_network" {
  value = {
    for host, params in var.hosts :
    host => [
      for if in host.hwif :
      chomp(templatefile("templates/libvirt_network.xml.tmpl", {
        p = params
        i = if
      }))
    ]
  }
}