output "ignition_snippets" {
  value = concat(
    local.module_ignition_snippets,
  )
}

output "tap_interfaces" {
  value = local.tap_interfaces
}

output "virtual_interfaces" {
  value = local.virtual_interfaces
}

output "hardware_interfaces" {
  value = local.hardware_interfaces
}