variable "addon_manifests" {
  type = map(string)
}

variable "addon_manifests_path" {
  type = string
}

variable "default_create_mode" {
  type    = string
  default = "EnsureExists"
}