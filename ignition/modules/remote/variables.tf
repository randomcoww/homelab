variable "ignition_version" {
  type = string
}

variable "tailscale_state_path" {
  type = string
}

variable "tailscale_auth_key" {
  type = string
}

variable "images" {
  type = object({
    tailscale = string
  })
}
