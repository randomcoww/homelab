provider "matchbox" {
  endpoint    = "${var.matchbox_rpc_endpoint}"
  client_cert = "${file("output/local.pem")}"
  client_key  = "${file("output/local-key.pem")}"
  ca          = "${file("output/ca.pem")}"
}
