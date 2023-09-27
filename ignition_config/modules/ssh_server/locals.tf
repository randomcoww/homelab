locals {
  users = [
    for _, user_name in var.user_names :
    {
      name = user_name
      ssh_authorized_keys = [
        "cert-authority ${chomp(var.ca.public_key_openssh)}"
      ]
    }
  ]

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      users = local.users
      pki = {
        server_private_key = {
          path    = "/etc/ssh/ssh_host_${lower(var.ca.algorithm)}_key"
          content = tls_private_key.ssh-host.private_key_pem
        }
        server_public_key = {
          path    = "/etc/ssh/ssh_host_${lower(var.ca.algorithm)}_key.pub"
          content = tls_private_key.ssh-host.public_key_openssh
        }
        server_certificate = {
          path    = "/etc/ssh/ssh_host_${lower(var.ca.algorithm)}_key-cert.pub"
          content = ssh_host_cert.ssh-host.cert_authorized_key
        }
      }
    })
  ]
}