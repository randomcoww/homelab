variable "name" {
  type = string
}

variable "app" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "replicas" {
  type    = number
  default = 1
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