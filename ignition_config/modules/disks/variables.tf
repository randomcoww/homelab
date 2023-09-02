variable "disks" {
  # type = map(object({
  #   device = string
  #   partitions = list(object({
  #     mount_path    = string
  #     start_mib     = optional(number)
  #     size_mib      = optional(number)
  #     wipe          = optional(bool)
  #     mount_timeout = optional(number)
  #     options       = optional(list(string))
  #     format        = optional(string)
  #   }))
  #   wipe = optional(bool)
  # }))
  type    = any
  default = {}
}

variable "bind_mounts" {
  type = list(object({
    path            = string
    target          = string
    systemd_require = string
  }))
}