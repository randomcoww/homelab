# Matchbox configs for PXE environment with matchbox renderer
module "vm" {
  source = "../modules/vm"

  ## user (default container linux)
  default_user      = "${local.default_user}"
  password          = "password"
  ssh_ca_public_key = "${tls_private_key.ssh_ca.public_key_openssh}"

  ## host configs
  vm_hosts   = ["vm-0", "vm-1"]
  vm_ips     = ["192.168.127.251", "192.168.127.252"]
  vm_if      = "enp1s0f0"
  vm_netmask = "23"
  mtu           = "9000"

  ## image
  container_linux_image_path = "/var/lib/tftpboot"
  container_linux_base_url   = "https://beta.release.core-os.net/amd64-usr"
  container_linux_version    = "current"

  ## renderer provisioning access
  renderer_endpoint        = "${local.local_renderer_endpoint}"
  renderer_cert_pem        = "${local.local_renderer_cert_pem}"
  renderer_private_key_pem = "${local.local_renderer_private_key_pem}"
  renderer_ca_pem          = "${local.local_renderer_ca_pem}"
}
