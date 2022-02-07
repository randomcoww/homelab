variable "manifests" {
  type = map(string)
}

variable "default_create_mode" {
  type    = string
  default = "EnsureExists"
}