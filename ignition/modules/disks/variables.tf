variable "ignition_version" {
  type = string
}

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

variable "mounts" {
  type    = any
  default = []
}