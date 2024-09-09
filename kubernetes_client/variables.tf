variable "smtp" {
  type = object({
    host     = string
    port     = string
    username = string
    password = string
  })
}

variable "wireguard_client" {
  type = object({
    private_key = string
    public_key  = string
    address     = string
    endpoint    = string
  })
  default = {
    private_key = ""
    public_key  = ""
    address     = ""
    endpoint    = ""
  }
}

variable "alpaca" {
  type = object({
    api_key_id     = string
    api_secret_key = string
    api_base_url   = string
  })
}