locals {
  params = {
    user = var.user
  }
}

output "client_params" {
  value = {
    ssh_ca_authorized_key  = tls_private_key.ssh-ca.public_key_openssh
    ssh_client_certificate = length(ssh_client_cert.ssh-client) > 0 ? ssh_client_cert.ssh-client[0].cert_authorized_key : ""
  }
}

output "ignition_server" {
  value = {
    for host, params in var.server_hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition_server/*") :
      templatefile(f, merge(local.params, {
        p                     = params
        ssh_ca_authorized_key = tls_private_key.ssh-ca.public_key_openssh
        ssh_host_private_key  = replace(tls_private_key.ssh-host[host].private_key_pem, "\n", "\\n")
        ssh_host_public_key   = tls_private_key.ssh-host[host].public_key_openssh
        ssh_host_certificate  = ssh_host_cert.ssh-host[host].cert_authorized_key
      }))
    ]
  }
}

output "ignition_client" {
  value = {
    for host, params in var.client_hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition_client/*") :
      templatefile(f, merge(local.params, {
        p                     = params
        ssh_ca_authorized_key = tls_private_key.ssh-ca.public_key_openssh
      }))
    ]
  }
}