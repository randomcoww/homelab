provider "matchbox" {
  endpoint    = "${var.matchbox_rpc_endpoint}"
  client_cert = "${file("/etc/ssl/certs/internal.pem")}"
  client_key  = "${file("/etc/ssl/certs/internal-key.pem")}"
  ca          = "${file("/etc/ssl/certs/internal-ca.pem")}"
}
