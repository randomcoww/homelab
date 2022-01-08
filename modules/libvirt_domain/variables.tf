variable "endpoint" {
  type = map(string)
}

# variable "name" {
#   type = string
# }

# variable "interface_devices" {
#   type    = any
#   default = {}
# }

# variable "guest_interface_device_order" {
#   type    = list(string)
#   default = []
# }

# variable "pxeboot_macaddress" {
#   type = string
# }

# variable "pxeboot_interface" {
#   type = string
# }

# variable "hypervisor_devices" {
#   type    = list(map(string))
#   default = []
# }

# variable "system_image_tag" {
#   type = string
# }

# variable "vcpu" {
#   type = number
# }

# variable "memory" {
#   type = number
# }

# cannot configure module as for_each when sneding provider config
variable "hosts" {
  type = any
}