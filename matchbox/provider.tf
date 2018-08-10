provider "matchbox" {
  endpoint    = "127.0.0.1:${var.matchbox_rpc_port}"
  client_cert = "${tls_locally_signed_cert.matchbox.cert_pem}"
  client_key  = "${tls_private_key.matchbox.private_key_pem}"
  ca          = "${tls_self_signed_cert.root.cert_pem}"
}

terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "matchbox/default.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
}
