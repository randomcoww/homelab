variable "ssh_client" {
  type = object({
    public_key_openssh    = string
    key_id                = string
    early_renewal_hours   = number
    validity_period_hours = number
  })
}

variable "wireguard_client" {
  type = object({
    private_key = string
    public_key  = string
    address     = string
    endpoint    = string
  })
}