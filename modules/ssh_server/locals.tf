locals {
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