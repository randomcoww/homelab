output "client_params" {
  value = {
    ssh_ca_authorized_key  = tls_private_key.ssh-ca.public_key_openssh
    ssh_client_certificate = length(ssh_client_cert.ssh-client) > 0 ? ssh_client_cert.ssh-client[0].cert_authorized_key : ""
  }
}

output "server_templates" {
  value = {
    for host, params in var.server_hosts :
    host => [
      for template in var.server_templates :
      templatefile(template, {
        user                  = var.user
        ssh_ca_authorized_key = tls_private_key.ssh-ca.public_key_openssh
        ssh_host_private_key  = replace(tls_private_key.ssh-host[host].private_key_pem, "\n", "\\n")
        ssh_host_public_key   = tls_private_key.ssh-host[host].public_key_openssh
        ssh_host_certificate  = ssh_host_cert.ssh-host[host].cert_authorized_key
      })
    ]
  }
}

output "client_templates" {
  value = {
    for host, params in var.client_hosts :
    host => [
      for template in var.client_templates :
      templatefile(template, {
        ssh_ca_authorized_key = tls_private_key.ssh-ca.public_key_openssh
      })
    ]
  }
}

output "addons" {
  value = {}
}