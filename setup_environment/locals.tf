locals {
  kubernetes_version       = "v1.11.2"
  renderer_endpoint        = "192.168.126.242:58081"
  renderer_cert_pem        = "${file("../setup_provisioner/output/matchbox/client.crt")}"
  renderer_private_key_pem = "${file("../setup_provisioner/output/matchbox/client.key")}"
  renderer_ca_pem          = "${file("../setup_provisioner/output/matchbox/ca.crt")}"
}
