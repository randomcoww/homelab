locals {
  global_params = {
    user                = var.user
    libvirt_tls_path = "/etc/pki"
    matchbox_tls_path = "/etc/matchbox/certs"
    matchbox_data_path   = "/etc/matchbox/data"
    matchbox_assets_path = "/etc/matchbox/assets"
    matchbox_http_port = 80
    matchbox_rpc_port = var.matchbox_rpc_port
    image_load_path  = "/var/lib/image-load"
    kea_config_path = "/etc/kea"

    networks = {
      for name, network in var.networks :
      name => merge(network, {
        cidr = split("/", network.network)[1]
      })
    }

    internal_interface = {
      name = "internal"
      network = var.internal_network
      ip = cidrhost(var.internal_network, 1)
      address = join("/",
        cidrhost(var.internal_network, 1),
        split("/", var.internal_network)[1],
      )
      dhcp_pool = cidrsubnet(var.internal_network, 1, 1)
    }
  }

  # https://www.terraform.io/language/functions/cidrsubnet
  host_interfaces = {
    for name, host in var.hosts :
    name => merge(host, {
      interfaces = {
        for interface_name, interface in host.interfaces :
        interface_name => merge(interface, {
          taps = {
            for network_name, tap in interface.taps :
            network_name => merge(tap, {
              ip = cidrhost(local.global_params.networks[tap.network].network, tap.netnum)
              address = join("/",
                cidrhost(local.global_params.networks[tap.network].network, tap.netnum),
                local.global_params.networks[tap.network].cidr,
              )
            })
          }
        })
      }
    })
  }

  host_certs = {
    for name, host in var.hosts :
    name => {
      matchbox_tls = {
        ca = {
          path = "ca.pem"
          content = tls_self_signed_cert.matchbox-ca.cert_pem
        }
        cert = {
          path = "cert.pem"
          content = tls_locally_signed_cert.matchbox[name].cert_pem
        }
        key = {
          path = "key.pem"
          content = tls_private_key.matchbox[name].private_key_pem
        }
      }
      libvirt_tls = {
        ca = {
          path = "CA/cacert.pem"
          content = tls_self_signed_cert.libvirt-ca.cert_pem
        }
        serverCert = {
          path = "libvirt/servercert.pem"
          content = tls_locally_signed_cert.libvirt[name].cert_pem
        }
        serverKey = {
          path = "libvirt/private/serverkey.pem"
          content = tls_private_key.libvirt[name].private_key_pem
        }
        clientCert = {
          path = "libvirt/clientcert.pem"
          content = tls_locally_signed_cert.libvirt[name].cert_pem
        }
        clientKey = {
          path = "libvirt/private/clientkey.pem"
          content = tls_private_key.libvirt[name].private_key_pem
        }
      }
    }
  }
}
