# Desktop credentials - pass in during apply
variable "desktop_user" {
  type    = string
  default = "randomcoww"
}

variable "desktop_password" {
  type    = string
  default = "password"
}

variable "ssh_client_public_key" {
  type    = string
  default = ""
}