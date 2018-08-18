# # Matchbox configs for PXE environment with matchbox renderer
# module "live" {
#   source = "../modules/live"
#   ## user (default container linux)
#   default_user      = "core"
#   ssh_ca_public_key = "${tls_private_key.ssh_ca.public_key_openssh}"
#   ## host configs
#   live_hosts     = ["live-0"]
#   live_macs      = ["00-1b-21-bc-67-c6"]
#   live_lan_ips   = ["192.168.62.252"]
#   live_store_ips = ["192.168.126.252"]
#   live_lan_if    = "ens1f1"
#   live_store_if  = "ens1f0"
#   ## images
#   hyperkube_image     = "gcr.io/google_containers/hyperkube:${local.kubernetes_version}"
#   fedora_live_version = "4.15.14-300.fc27.x86_64"
#   ## ports
#   matchbox_http_port = "58080"
#   ## vip
#   matchbox_vip = "192.168.126.242"
#   # ## ip ranges
#   lan_netmask   = "${locals.lan_netmask}"
#   store_netmask = "${locals.store_netmask}"
#   ## renderer provisioning access
#   renderer_endpoint        = "${local.renderer_endpoint}"
#   renderer_cert_pem        = "${local.renderer_cert_pem}"
#   renderer_private_key_pem = "${local.renderer_private_key_pem}"
#   renderer_ca_pem          = "${local.renderer_ca_pem}"
# }

