variable "members" {
  type = map(object({
    interface_name = string
    mac            = string
  }))
}