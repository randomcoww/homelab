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

  live_hosts     = ["live-0"]
  live_macs      = ["00-1b-21-bc-67-c6"]
  live_lan_ips   = ["192.168.62.252"]
  live_store_ips = ["192.168.126.252"]
  live_lan_if    = "ens1f1"
  live_store_if  = "ens1f0"

  ## images
  hyperkube_image     = "gcr.io/google_containers/hyperkube:v1.11.0"
  fedora_live_version = "4.15.14-300.fc27.x86_64"

  ## ports
  matchbox_http_port = "58080"

  ## vip
  matchbox_vip = "192.168.126.242"

  # ## ip ranges
  lan_netmask   = "23"
  store_netmask = "23"

  ## renderer provisioning access
  renderer_endpoint        = "127.0.0.1:8081"
  renderer_cert_pem        = "${file("../renderer/output/server.crt")}"
  renderer_private_key_pem = "${file("../renderer/output/server.key")}"
  renderer_ca_pem          = "${file("../renderer/output/ca.crt")}"
}
