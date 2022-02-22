provider "matchbox" {
  endpoint    = local.pxeboot.matchbox_api_endpoint
  client_cert = file("output/certs/matchbox-cert.pem")
  client_key  = file("output/certs/matchbox-key.pem")
  ca          = file("output/certs/matchbox-ca.pem")
}