# Matchbox configs for PXE environment with matchbox renderer
module "renderer" {
  source = "../modules/renderer"
}

resource "local_file" "ca_pem" {
  content  = "${chomp(module.renderer.matchbox_ca_pem)}"
  filename = "output/renderer/ca.crt"
}

resource "local_file" "matchbox_private_key_pem" {
  content  = "${chomp(module.renderer.matchbox_private_key_pem)}"
  filename = "output/renderer/server.key"
}

resource "local_file" "matchbox_cert_pem" {
  content  = "${chomp(module.renderer.matchbox_cert_pem)}"
  filename = "output/renderer/server.crt"
}
