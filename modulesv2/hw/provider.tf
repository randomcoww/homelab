provider "matchbox" {
  endpoint    = var.renderer.endpoint
  client_cert = var.renderer.cert_pem
  client_key  = var.renderer.private_key_pem
  ca          = var.renderer.ca_pem
}
