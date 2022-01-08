variable "endpoint" {
  type = map(string)
}

# variable "name" {
#   type = string
# }

# variable "kernel" {
#   type = string
# }

# variable "initrd" {
#   type = list(string)
# }

# variable "args" {
#   type = list(string)
# }

# variable "raw_ignition" {
#   type = string
# }

# variable "pxeboot_macaddress" {
#   type = string
# }

# cannot configure module as for_each when sneding provider config
variable "hosts" {
  type = any
}