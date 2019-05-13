locals {
  local_renderer_endpoint        = "127.0.0.1:8081"
  local_renderer_cert_pem        = "${module.renderer.matchbox_cert_pem}"
  local_renderer_private_key_pem = "${module.renderer.matchbox_private_key_pem}"
  local_renderer_ca_pem          = "${module.renderer.matchbox_ca_pem}"

  matchbox_vip       = "192.168.126.242"
  matchbox_http_port = "58080"
  matchbox_rpc_port  = "58081"

  renderer_endpoint        = "${local.matchbox_vip}:${local.matchbox_rpc_port}"
  renderer_cert_pem        = "${module.provisioner.matchbox_cert_pem}"
  renderer_private_key_pem = "${module.provisioner.matchbox_private_key_pem}"
  renderer_ca_pem          = "${module.provisioner.matchbox_ca_pem}"

  recursive_dns_vip = "192.168.126.241"
  internal_dns_vip  = "192.168.126.127"
  store_gateway_vip = "192.168.126.240"
  internal_domain   = "fuzzybunny.internal"

  default_user = "core"

  subnet_store_netmask = "23"
  subnet_lan_netmask   = "23"
  subnet_sync_netmask  = "29"
  subnet_ll_netmask    = "16"

  ## VM access to host
  host_ll_ip = "169.254.169.254"

  default_mtu = "9000"

  ## image
  container_linux_image_path = "/var/lib/tftpboot"
  container_linux_base_url   = "https://beta.release.core-os.net/amd64-usr"
  container_linux_version    = "current"
}
