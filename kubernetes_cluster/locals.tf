locals {
  kubernetes_version       = "v1.11.2"
  renderer_endpoint        = "127.0.0.1:8081"
  renderer_cert_pem        = "${file("../renderer/output/server.crt")}"
  renderer_private_key_pem = "${file("../renderer/output/server.key")}"
  renderer_ca_pem          = "${file("../renderer/output/ca.crt")}"
}
