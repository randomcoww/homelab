variable "ssh_client_public_key_openssh" {
  type = string
}

variable "ssh_client_key_id" {
  type = string
}

variable "ssh_client_early_renewal_hours" {
  type    = number
  default = 168
}

variable "ssh_client_validity_period_hours" {
  type    = number
  default = 336
}