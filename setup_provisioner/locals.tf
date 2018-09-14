locals {
  kubernetes_version       = "v1.11.3"
  renderer_endpoint        = "127.0.0.1:8081"
  renderer_cert_pem        = "${file("../setup_renderer/output/server.crt")}"
  renderer_private_key_pem = "${file("../setup_renderer/output/server.key")}"
  renderer_ca_pem          = "${file("../setup_renderer/output/ca.crt")}"
}
