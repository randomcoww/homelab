# User override (local.preprocess.users)
variable "users" {
  type    = any
  default = {}
}

variable "tailscale" {
  type = object({
    auth_key = string
  })
}