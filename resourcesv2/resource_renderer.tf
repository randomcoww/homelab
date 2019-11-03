# Matchbox configs for PXE environment with matchbox renderer
module "renderer" {
  source = "../modulesv2/renderer"
}

resource "local_file" "matchbox-ca-pem" {
  content  = chomp(module.renderer.matchbox_ca_pem)
  filename = "output/renderer/ca.crt"
}

resource "local_file" "matchbox-private-key-pem" {
  content  = chomp(module.renderer.matchbox_private_key_pem)
  filename = "output/renderer/server.key"
}

resource "local_file" "matchbox-cert-pem" {
  content  = chomp(module.renderer.matchbox_cert_pem)
  filename = "output/renderer/server.crt"
}
