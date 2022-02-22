variable "user_names" {
  type    = list(string)
  default = []
}

variable "key_id" {
  type = string
}

variable "valid_principals" {
  type    = list(string)
  default = []
}

variable "early_renewal_hours" {
  type    = number
  default = 8040
}

variable "validity_period_hours" {
  type    = number
  default = 8760
}

variable "ca" {
  type = object({
    algorithm          = string
    private_key_pem    = string
    public_key_openssh = string
  })
}