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

  domain_templates = {
    "coreos" = "${path.module}/templates/libvirt/domain_coreos.xml"
  }

  network_templates = {
    "vf" = "${path.module}/templates/libvirt/network_vf.xml"
  }
}

output "matchbox_rpc_endpoints" {
  value = {
    for host, params in var.hosts :
    host => {
      endpoint        = "${params.networks_by_key.internal.ip}:${var.services.renderer.ports.rpc}"
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
      endpoint        = "qemu://${params.networks_by_key.internal.ip}/system"
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
      for f in fileset(".", "${path.module}/templates/ignition/*") :
      templatefile(f, merge(local.params, {
        p                = params
        tls_matchbox_ca  = tls_self_signed_cert.matchbox-ca.cert_pem
        tls_matchbox     = tls_locally_signed_cert.matchbox[host].cert_pem
        tls_matchbox_key = tls_private_key.matchbox[host].private_key_pem
        tls_libvirt_ca   = tls_self_signed_cert.libvirt-ca.cert_pem
        tls_libvirt      = tls_locally_signed_cert.libvirt[host].cert_pem
        tls_libvirt_key  = tls_private_key.libvirt[host].private_key_pem
      }))
    ]
  }
}

output "libvirt_domain" {
  value = {
    for host, params in var.hosts :
    host => {
      for guest in params.libvirt_domains :
      guest.node => chomp(templatefile(local.domain_templates[lookup(guest, "type", "coreos")], {
        p    = params
        g    = guest.host
        hwif = guest.hwif
      }))
    }
  }
}

output "libvirt_network" {
  value = {
    for host, params in var.hosts :
    host => {
      for if in params.hwif :
      if.label => chomp(templatefile(local.network_templates[lookup(if, "type", "vf")], {
        p = params
        i = if
      }))
    }
  }
}