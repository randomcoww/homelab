variable "ignition_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "key_id" {
  type = string
}

variable "ca" {
  type = object({
    algorithm          = string
    private_key_pem    = string
    public_key_openssh = string
  })
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