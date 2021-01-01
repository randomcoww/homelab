variable "users" {
  type = any
}

variable "domains" {
  type = map(string)
}

variable "services" {
  type = any
}

variable "networks" {
  type = any
}

variable "container_images" {
  type = map(string)
}

variable "wireguard_config" {
  type = any
}

variable "hosts" {
  type = any
}

variable "syncthing_directories" {
  type = map(string)
}