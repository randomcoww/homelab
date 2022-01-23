variable "hardware_interface_name" {
  type = string
}

variable "source_interface_name" {
  type = string
}

variable "bridge_interface_name" {
  type    = string
  default = "br-wlan"
}

variable "bridge_interface_mtu" {
  type    = number
  default = 1500
}

variable "ssid" {
  type = string
}

variable "passphrase" {
  type = string
}

variable "hostapd_container_image" {
  type = string
}

variable "static_pod_manifest_path" {
  type    = string
  default = "/var/lib/kubelet/manifests"
}