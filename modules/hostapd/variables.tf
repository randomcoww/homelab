variable "hardware_interface_name" {
  type = string
}

variable "vlan_interface_name" {
  type = string
}

variable "br_interface_name" {
  type = string
}

variable "roaming_mobility_domain" {
  type = string
}

variable "ssid" {
  type = string
}

variable "passphrase" {
  type = string
}

variable "nasid" {
  type = string
}

variable "hostapd_container_image" {
  type = string
}

variable "static_pod_manifest_path" {
  type    = string
  default = "/var/lib/kubelet/manifests"
}