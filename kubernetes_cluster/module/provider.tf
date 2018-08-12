provider "matchbox" {
  endpoint    = "${var.renderer_endpoint}"
  client_cert = "${var.renderer_cert_pem}"
  client_key  = "${var.renderer_private_key_pem}"
  ca          = "${var.renderer_ca_pem}"
}