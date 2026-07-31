locals {

  # SSH CA keys
  ssh_config_files = {
    private_key = {
      mode = 384
      path = "/etc/ssh/ssh_host_${lower(var.ssh_ca.algorithm)}_key"
      contents = {
        inline = tls_private_key.ssh-host.private_key_pem
      }
    }
    public_key = {
      mode = 384
      path = "/etc/ssh/ssh_host_${lower(var.ssh_ca.algorithm)}_key.pub"
      contents = {
        inline = tls_private_key.ssh-host.public_key_openssh
      }
    }
    certificate = {
      mode = 384
      path = "/etc/ssh/ssh_host_${lower(var.ssh_ca.algorithm)}_key-cert.pub"
      contents = {
        inline = ssh_host_cert.ssh-host.cert_authorized_key
      }
    }
    known_hosts = {
      mode = 420
      path = "/etc/ssh/ssh_known_hosts"
      contents = {
        inline = "@cert-authority * ${chomp(var.ssh_ca.public_key_openssh)}"
      }
    }
  }
}