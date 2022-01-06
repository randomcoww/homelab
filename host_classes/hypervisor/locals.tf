locals {
  networks = {
    for network_name, network in var.networks :
    network_name => merge(network, try({
      prefix = "${network.network}/${network.cidr}"
    }, {}))
  }

  hardware_interfaces = {
    for interface_name, interface in var.hardware_interfaces :
    interface_name => merge(interface, {
      networks = {
        for network_name, network in lookup(interface, "networks", {}) :
        network_name => merge(local.networks[network_name], network, {
          "interface_name" = "${interface_name}-${network_name}"
        })
      }
    })
  }

  internal_interface = merge({
    netnum         = 1
    interface_name = "internal"
    dhcp_subnet = {
      newbit = 1
      netnum = 1
    }
  }, local.networks.internal)

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