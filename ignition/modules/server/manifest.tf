locals {
  pki = {
    server-private-key = {
      path     = "/etc/ssh/ssh_host_${lower(var.ca.algorithm)}_key"
      contents = tls_private_key.ssh-host.private_key_pem
    }
    server-public-key = {
      path     = "/etc/ssh/ssh_host_${lower(var.ca.algorithm)}_key.pub"
      contents = tls_private_key.ssh-host.public_key_openssh
    }
    server-certificate = {
      path     = "/etc/ssh/ssh_host_${lower(var.ca.algorithm)}_key-cert.pub"
      contents = ssh_host_cert.ssh-host.cert_authorized_key
    }
    authorized-keys = {
      path     = "/etc/ssh/authorized_keys"
      contents = "cert-authority ${chomp(var.ca.public_key_openssh)}"
      mode     = 420
    }
    known-hosts = {
      path     = "/etc/ssh/ssh_known_hosts"
      contents = "@cert-authority * ${chomp(var.ca.public_key_openssh)}"
      mode     = 420
    }
  }

  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version = var.ignition_version
      pki              = local.pki
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.ignition_version
      storage = {
        files = [
          for _, f in concat(
            values(local.pki),
          ) :
          merge({
            mode = 384
            }, f, {
            contents = {
              inline = f.contents
            }
          })
        ]
      }
    }),
  ])
}