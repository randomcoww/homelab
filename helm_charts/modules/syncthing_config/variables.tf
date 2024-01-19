variable "hostnames" {
  type    = list(string)
  default = []
}

variable "ports" {
  type = object({
    syncthing_peer = number
  })
}

variable "syncthing_home_path" {
  type    = string
  default = "/var/lib/syncthing"
}

variable "sync_data_paths" {
  type = list(string)
}