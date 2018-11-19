# Matchbox configs for PXE environment with matchbox renderer
module "desktop" {
  source = "../modules/desktop"

  ## user (default container linux)
  default_user = "randomcoww"
  password     = "$1$Tfw58onC$LlmO0qsSa9WAsRh0bJwzW0"

  ## host configs
  desktop_hosts = ["desktop-0"]
  desktop_ips   = ["192.168.126.253"]
  desktop_if    = "eno1"
  mtu           = "9000"

  ## ip ranges
  netmask = "23"

  ## renderer provisioning access
  renderer_endpoint        = "${local.renderer_endpoint}"
  renderer_cert_pem        = "${local.renderer_cert_pem}"
  renderer_private_key_pem = "${local.renderer_private_key_pem}"
  renderer_ca_pem          = "${local.renderer_ca_pem}"
}
