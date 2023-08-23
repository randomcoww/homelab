variable "ssh_client" {
  type = object({
    public_key            = string
    key_id                = string
    early_renewal_hours   = number
    validity_period_hours = number
  })
}