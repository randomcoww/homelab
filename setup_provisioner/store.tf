# Matchbox configs for PXE environment with matchbox renderer
module "store" {
  source = "../modules/store"

  ## user (default container linux)
  default_user      = "core"
  password          = "password"
  ssh_ca_public_key = "${tls_private_key.ssh_ca.public_key_openssh}"

  ## host configs
  store_hosts   = ["store-0", "store-1"]
  store_ips     = ["192.168.127.251", "192.168.127.252"]
  store_if      = "enp1s0f0"
  store_netmask = "23"
  mtu           = "9000"

  ## image
  container_linux_image_path = "/var/lib/tftpboot"
  container_linux_base_url   = "https://beta.release.core-os.net/amd64-usr"
  container_linux_version    = "current"

  ## renderer provisioning access
  renderer_endpoint        = "${local.renderer_endpoint}"
  renderer_cert_pem        = "${local.renderer_cert_pem}"
  renderer_private_key_pem = "${local.renderer_private_key_pem}"
  renderer_ca_pem          = "${local.renderer_ca_pem}"
}
