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
    known-hosts = {
      path     = "/etc/ssh/ssh_known_hosts"
      contents = "@cert-authority * ${chomp(var.ca.public_key_openssh)}"
      mode     = 420
    }
  }

  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      butane_version = var.butane_version
      fw_mark        = var.fw_mark
      # SSH
      pki = local.pki
      # HA config
      keepalived_path       = var.keepalived_path
      bird_path             = var.bird_path
      haproxy_path          = var.haproxy_path
      bird_cache_table_name = var.bird_cache_table_name
      bgp_router_id         = var.bgp_router_id
      bgp_port              = var.bgp_port
      cni_bin_path          = var.cni_bin_path
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.butane_version
      passwd = {
        users = [
          merge(var.user, {
            ssh_authorized_keys = [
              "cert-authority ${chomp(var.ca.public_key_openssh)}",
            ]
          }),
        ]
      }
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