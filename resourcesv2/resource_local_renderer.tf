## Use local matchbox renderer launched with run_renderer.sh
module "local-renderer" {
  source = "../modulesv2/renderer"
}

resource "local_file" "matchbox-ca-pem" {
  content  = chomp(module.local-renderer.matchbox_ca_pem)
  filename = "output/local-renderer/ca.crt"
}

resource "local_file" "matchbox-private-key-pem" {
  content  = chomp(module.local-renderer.matchbox_private_key_pem)
  filename = "output/local-renderer/server.key"
}

resource "local_file" "matchbox-cert-pem" {
  content  = chomp(module.local-renderer.matchbox_cert_pem)
  filename = "output/local-renderer/server.crt"
}