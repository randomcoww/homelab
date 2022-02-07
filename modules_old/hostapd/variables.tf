variable "hardware_interface_name" {
  type = string
}

variable "bssid" {
  type = string
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

variable "mobility_domain" {
  type = string
}

variable "encryption_key" {
  type = string
}

variable "roaming_members" {
  type = list(object({
    name  = string
    bssid = string
  }))
}

variable "static_pod_manifest_path" {
  type = string
}