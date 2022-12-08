provider "matchbox" {
  endpoint    = local.matchbox_api_endpoint
  client_cert = file("output/certs/matchbox-bootstrap-cert.pem")
  client_key  = file("output/certs/matchbox-bootstrap-key.pem")
  ca          = file("output/certs/matchbox-bootstrap-ca.pem")
}