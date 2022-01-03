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

  certs = {
    ca_authorized_key = {
      content = var.ca.ssh.public_key_openssh
    }
    server_private_key = {
      path    = "/etc/ssh/ssh_host_${lower(var.ca.ssh.algorithm)}_key"
      content = tls_private_key.ssh-host.private_key_pem
    }
    server_public_key = {
      path    = "/etc/ssh/ssh_host_${lower(var.ca.ssh.algorithm)}_key.pub"
      content = tls_private_key.ssh-host.public_key_openssh
    }
    server_certificate = {
      path    = "/etc/ssh/ssh_host_${lower(var.ca.ssh.algorithm)}_key-cert.pub"
      content = ssh_host_cert.ssh-host.cert_authorized_key
    }
  }
}