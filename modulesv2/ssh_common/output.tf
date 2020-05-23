output "ssh_ca_private_key" {
  value = tls_private_key.ssh-ca.private_key_pem
}

output "ssh_ca_authorized_key" {
  value = tls_private_key.ssh-ca.public_key_openssh
}

output "templates" {
  value = {
    for k in keys(var.ssh_hosts) :
    k => [
      for template in var.ssh_templates :
      templatefile(template, {
        user                  = var.user
        ssh_ca_authorized_key = tls_private_key.ssh-ca.public_key_openssh
        ssh_host_private_key  = replace(tls_private_key.ssh-host[k].private_key_pem, "\n", "\\n")
        ssh_host_public_key   = tls_private_key.ssh-host[k].public_key_openssh
        ssh_host_certificate  = sshca_host_cert.ssh-host[k].cert_authorized_key
      })
    ]
  }
}