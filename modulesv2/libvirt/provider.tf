provider "libvirt" {
  endpoint    = var.client.endpoint
  client_cert = var.client.cert_pem
  client_key  = var.client.private_key_pem
  ca          = var.client.ca_pem
}