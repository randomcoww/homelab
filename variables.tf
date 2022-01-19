# User override (local.preprocess.users)
variable "users" {
  type    = any
  default = {}
}

# SSH client for local user
variable "ssh_client" {
  type = object({
    public_key            = string
    key_id                = string
    early_renewal_hours   = number
    validity_period_hours = number
  })
}

variable "wifi" {
  type = object({
    ssid       = string
    passphrase = string
  })
}