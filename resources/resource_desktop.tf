# Matchbox configs for PXE environment with matchbox renderer
module "desktop" {
  source = "../modules/desktop"

  ## user (default container linux)
  default_user      = "${local.default_user}"
  desktop_user      = "randomcoww"
  password          = "password"
  ssh_ca_public_key = "${tls_private_key.ssh_ca.public_key_openssh}"

  ## host configs
  desktop_hosts   = ["desktop-0"]
  desktop_ips     = ["192.168.127.253"]
  desktop_if      = "eno2"
  desktop_netmask = "23"
  mtu             = "9000"

  ## renderer provisioning access
  renderer_endpoint        = "${local.renderer_endpoint}"
  renderer_cert_pem        = "${local.renderer_cert_pem}"
  renderer_private_key_pem = "${local.renderer_private_key_pem}"
  renderer_ca_pem          = "${local.renderer_ca_pem}"
}
