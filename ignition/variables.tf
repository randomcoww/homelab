# User override (local.preprocess.users)
variable "users" {
  type    = any
  default = {}
}

variable "wireguard_client" {
  type = object({
    private_key = string
    public_key  = string
    address     = string
    endpoint    = string
    dns         = string
    allowed_ips = string
  })
  default = {
    private_key = ""
    public_key  = ""
    address     = ""
    endpoint    = ""
    dns         = ""
    allowed_ips = ""
  }
}