locals {
  pki = {
    ca-public-key-openssh = {
      path     = "/etc/ssh/ssh_known_hosts"
      contents = "@cert-authority * ${chomp(var.public_key_openssh)}"
      mode     = 420
    }
  }

  ignition_snippets = [
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
  ]
}