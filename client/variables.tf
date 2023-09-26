variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "ssh_client" {
  type = object({
    public_key_openssh    = string
    key_id                = string
    early_renewal_hours   = number
    validity_period_hours = number
  })
}