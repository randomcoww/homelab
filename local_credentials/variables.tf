variable "ssh_client" {
  type = object({
    public_key_openssh    = string
    key_id                = string
    early_renewal_hours   = optional(number, 168)
    validity_period_hours = optional(number, 336)
  })
}