# Matchbox configs for PXE environment with matchbox renderer
module "store" {
  source = "../modules/store"

  ## user (default container linux)
  default_user      = "core"
  password          = "password"
  ssh_ca_public_key = "${tls_private_key.ssh_ca.public_key_openssh}"

  ## host configs
  store_hosts = ["store-0"]
  store_ips   = ["192.168.126.251"]
  store_if    = "enp1s0f0"
  mtu         = "9000"

  ## images
  hyperkube_image = "gcr.io/google_containers/hyperkube:${local.kubernetes_version}"

  ## ip ranges
  netmask = "23"

  ## renderer provisioning access
  renderer_endpoint        = "${local.renderer_endpoint}"
  renderer_cert_pem        = "${local.renderer_cert_pem}"
  renderer_private_key_pem = "${local.renderer_private_key_pem}"
  renderer_ca_pem          = "${local.renderer_ca_pem}"
}
