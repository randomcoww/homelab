# module "hostapd-common" {
#   source = "./modules/hostapd_common"
# }

# module "ignition-hostapd" {
#   for_each = {
#     for host_key in [
#       "aio-0",
#     ] :
#     host_key => local.hosts[host_key]
#   }

#   source                   = "./modules/hostapd"
#   ssid                     = var.wifi.ssid
#   passphrase               = var.wifi.passphrase
#   hardware_interface_name  = "wlan0"
#   source_interface_name    = "phy0"
#   bridge_interface_mtu     = each.value.hardware_interfaces.phy0.mtu
#   hostapd_container_image  = local.container_images.hostapd
#   static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
#   bssid                    = replace(each.value.hardware_interfaces.wlan0.mac, "-", ":")
#   hostapd_mobility_domain  = random_id.hostapd-mobility-domain.hex
#   hostapd_encryption_key   = random_id.hostapd-encryption-key.hex
#   hostapd_roaming_members = [
#     for host in [
#       local.hosts.aio-0,
#     ] :
#     {
#       name  = host.hostname
#       bssid = replace(host.hardware_interfaces.wlan0.mac, "-", ":")
#     }
#   ]
# }