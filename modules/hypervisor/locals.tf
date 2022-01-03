locals {
  vlans = {
    for name, vlan in var.vlans :
    name => merge(vlan, {
      cidr = split("/", vlan.network)[1]
    })
  }

  interfaces = {
    for interface_name, interface in var.interfaces :
    interface_name => merge(interface, {
      taps = {
        for network_name, tap in interface.taps :
        network_name => merge(tap, {
          ip = cidrhost(local.vlans[network_name].network, tap.netnum)
          address = join("/", [
            cidrhost(local.vlans[network_name].network, tap.netnum),
            local.vlans[network_name].cidr,
          ])
        })
      }
    })
  }

  internal_interface = {
    name    = "internal"
    network = var.internal_vlan
    ip      = cidrhost(var.internal_vlan, 1)
    address = join("/", [
      cidrhost(var.internal_vlan, 1),
      split("/", var.internal_vlan)[1],
    ])
    dhcp_pool = cidrsubnet(var.internal_vlan, 1, 1)
  }

  certs = {
    matchbox = {
      ca = {
        path    = "/etc/matchbox/ca.pem"
        content = var.ca.matchbox.cert_pem
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
        content = var.ca.libvirt.cert_pem
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
