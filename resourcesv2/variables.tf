# Password for admin - pass in during apply
variable "password" {
  type    = string
  default = "password"
}

# Pick Matchbox instance to send config to
# "local" for testing
variable "renderer" {
  type    = string
  default = "local"
}