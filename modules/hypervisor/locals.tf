locals {
  certs = {
    libvirt = {
      ca_cert = {
        path    = "/etc/pki/CA/cacert.pem"
        content = var.libvirt_ca.cert_pem
      }
      server_cert = {
        path    = "/etc/pki/libvirt/servercert.pem"
        content = tls_locally_signed_cert.libvirt.cert_pem
      }
      server_key = {
        path    = "/etc/pki/libvirt/private/serverkey.pem"
        content = tls_private_key.libvirt.private_key_pem
      }
      client_cert = {
        path    = "/etc/pki/libvirt/clientcert.pem"
        content = tls_locally_signed_cert.libvirt.cert_pem
      }
      client_key = {
        path    = "/etc/pki/libvirt/private/clientkey.pem"
        content = tls_private_key.libvirt.private_key_pem
      }
    }
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      certs = local.certs.libvirt
    })
  ]

  libvirt_endpoints = {
    for network_name, network in var.networks :
    network_name => concat([
      for interface in values(var.interfaces) :
      "qemu://${cidrhost(interface.prefix, var.host_netnum)}/system"
      if lookup(interface, "enable_netnum", false)
    ])
  }
}