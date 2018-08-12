# Matchbox configs for PXE environment with matchbox renderer
module "store" {
  source = "./module_store"

  ## user (default container linux)
  default_user      = "core"
  ssh_ca_public_key = "${tls_private_key.ssh_ca.public_key_openssh}"

  ## host configs
  store_hosts     = ["store-0"]
  store_lan_ips   = ["192.168.62.251"]
  store_store_ips = ["192.168.126.251"]
  store_lan_if    = "ens1f1"
  store_store_if  = "ens1f0"

  ## images
  hyperkube_image = "gcr.io/google_containers/hyperkube:${local.kubernetes_version}"

  # ## ip ranges
  lan_netmask   = "23"
  store_netmask = "23"

  ## renderer provisioning access
  renderer_endpoint        = "${local.renderer_endpoint}"
  renderer_cert_pem        = "${local.renderer_cert_pem}"
  renderer_private_key_pem = "${local.renderer_private_key_pem}"
  renderer_ca_pem          = "${local.renderer_ca_pem}"
}
