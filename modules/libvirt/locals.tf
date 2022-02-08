locals {
  certs = merge(var.certs, {
    server_cert = {
      content = tls_locally_signed_cert.libvirt.cert_pem
      path    = "/etc/pki/libvirt/servercert.pem"
    }
    server_key = {
      content = tls_private_key.libvirt.private_key_pem
      path    = "/etc/pki/libvirt/private/serverkey.pem"
    }
    client_cert = {
      content = tls_locally_signed_cert.libvirt.cert_pem
      path    = "/etc/pki/libvirt/clientcert.pem"
    }
    client_key = {
      content = tls_private_key.libvirt.private_key_pem
      path    = "/etc/pki/libvirt/private/clientkey.pem"
    }
  })

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      certs = local.certs
    })
  ]
}