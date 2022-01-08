provider "matchbox" {
  endpoint    = var.endpoint.endpoint
  client_cert = var.endpoint.cert_pem
  client_key  = var.endpoint.private_key_pem
  ca          = var.endpoint.ca_pem
}