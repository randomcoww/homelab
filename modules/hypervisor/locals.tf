locals {
  networks = {
    for network_name, network in var.networks :
    network_name => merge(network, try({
      prefix = "${network.network}/${network.cidr}"
    }, {}))
  }

  hardware_interfaces = {
    for hardware_interface_name, hardware_interface in var.hardware_interfaces :
    hardware_interface_name => merge(hardware_interface, {
      interfaces = {
        for network_name, network in lookup(hardware_interface, "interfaces", {}) :
        network_name => merge(local.networks[network_name], network, {
          "interface_name" = "${hardware_interface_name}-${network_name}"
        })
      }
    })
  }

  # this is not seen outside of host and can be replicated on all hosts
  internal_interface = merge(local.networks.internal, var.internal_interface)

  certs = {
    matchbox = {
      ca = {
        path    = "/etc/matchbox/ca.pem"
        content = var.matchbox_ca.cert_pem
      }
      cert = {
        path    = "/etc/matchbox/cert.pem"
        content = tls_locally_signed_cert.matchbox.cert_pem
      }
      key = {
        path    = "/etc/matchbox/key.pem"
        content = tls_private_key.matchbox.private_key_pem
      }
    }
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