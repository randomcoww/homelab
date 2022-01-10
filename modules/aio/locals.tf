locals {
  # assign names for guest interfaces by order
  # libvirt assigns names ens2, ens3 ... ensN in order defined in domain XML
  tap_interfaces = {
    for network_name, tap_interface in var.tap_interfaces :
    network_name => merge(var.networks[network_name], tap_interface, {
      interface_name      = network_name
      vmac_interface_name = "${network_name}-vmac"
    })
  }

  certs = {
    libvirt = {
      ca = {
        path    = "/etc/pki/CA/cacert.pem"
        content = var.libvirt_ca.cert_pem
      }
      serverCert = {
        path    = "/etc/pki/libvirt/servercert.pem"
        content = tls_locally_signed_cert.libvirt.cert_pem
      }
      serverKey = {
        path    = "/etc/pki/libvirt/private/serverkey.pem"
        content = tls_private_key.libvirt.private_key_pem
      }
      clientCert = {
        path    = "/etc/pki/libvirt/clientcert.pem"
        content = tls_locally_signed_cert.libvirt.cert_pem
      }
      clientKey = {
        path    = "/etc/pki/libvirt/private/clientkey.pem"
        content = tls_private_key.libvirt.private_key_pem
      }
    }
  }
}