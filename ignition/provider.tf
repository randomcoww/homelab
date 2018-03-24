provider "matchbox" {
  endpoint    = "${var.matchbox_rpc_endpoint}"
  client_cert = "${file("/etc/ssl/certs/matchbox.pem")}"
  client_key  = "${file("/etc/ssl/certs/matchbox-key.pem")}"
  ca          = "${file("/etc/ssl/certs/matchbox-ca.pem")}"
}
