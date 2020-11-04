# (Optional) Local login. SSH only otherwise.
variable "client_password" {
  type    = string
  default = ""
}

# (Optional) Pass in client public key to sign it
variable "ssh_client_public_key" {
  type    = string
  default = ""
}

# (Optional) Add Interface and Peer configs:
# Interface = {
#   PrivateKey =
#   Address =
#   DNS =
# }
# Peer = {
#   PublicKey =
#   AllowedIPs =
#   Endpoint =
# }
variable "wireguard_config" {
  type    = any
  default = {}
}