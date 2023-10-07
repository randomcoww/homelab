variable "wlan_interface" {
  type = string
}

variable "tailscale_ssm_access" {
  type = object({
    access_key_id     = string
    secret_access_key = string
    aws_region        = string
    resource          = string
  })
}