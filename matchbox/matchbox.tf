provider "matchbox" {
  endpoint    = "127.0.0.1:${var.matchbox_rpc_port}"
  client_cert = "${file("output/matchbox.pem")}"
  client_key  = "${file("output/matchbox-key.pem")}"
  ca          = "${file("output/ca.pem")}"
}
