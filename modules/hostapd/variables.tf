variable "host_key" {
  type = string
}

variable "ssid" {
  type = string
}

variable "passphrase" {
  type = string
}

variable "roaming_members" {
  type = map(object({
    interface_name  = string
    mac             = string
    bssid           = string
    nas_identifier  = string
    mobility_domain = string
    encryption_key  = string
  }))
}

variable "ht_capab" {
  type = list(string)
  default = [
    "LDPC",
    "HT40-",
    "HT40+",
    "VHT160",
    "SHORT-GI-40",
    "SHORT-GI-160",
    "TX-STBC",
    "RX-STBC1",
    "DSSS_CCK-40",
  ]
}