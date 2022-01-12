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
}