locals {
  globalParams = {
    user = var.user
  }

  hostParams = {
    for host, params in var.hosts :
    host => merge(globalParams, {
      ssh = {
        ca_authorized_key = {
          content = tls_private_key.ssh-ca.public_key_openssh
        }
        server_private_key = {
          path = "/etc/ssh/ssh_host_${lower(tls_private_key.ssh-ca.algorithm)}_key"
          content = tls_private_key.ssh-host[host].private_key_pem
        }
        server_public_key = {
          path = "/etc/ssh/ssh_host_${lower(tls_private_key.ssh-ca.algorithm)}_key.pub"
          content = tls_private_key.ssh-host[host].public_key_openssh
        }
        server_certificate = {
          path = "/etc/ssh/ssh_host_${lower(tls_private_key.ssh-ca.algorithm)}_key-cert.pub"
          content = ssh_host_cert.ssh-host[host].cert_authorized_key
        }
      }
    })
  }
}

output "ignition_server" {
  value = {
    for host in var.server_hosts :
    host => [
      for f in fileset(".", "${path.module}/ignition/server.yaml") :
      templatefile(f, hostParams)
    ]
  }
}

output "ignition_client" {
  value = {
    for host in var.client_hosts :
    host => [
      for f in fileset(".", "${path.module}/ignition/client.yaml") :
      templatefile(f, hostParams)
    ]
  }
}

output "client_params" {
  value = {
    ssh_ca_authorized_key  = tls_private_key.ssh-ca.public_key_openssh
    ssh_client_certificate = length(ssh_client_cert.ssh-client) > 0 ? ssh_client_cert.ssh-client[0].cert_authorized_key : ""
  }
}