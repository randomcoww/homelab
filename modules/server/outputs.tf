output "ignition_snippets" {
  value = concat(
    local.module_ignition_snippets,
  )
}

output "interfaces" {
  value = local.tap_interfaces
}

output "hardware_interfaces" {
  value = local.hardware_interfaces
}