output "ignition_snippets" {
  value = concat(
    local.module_ignition_snippets,
    local.common_ignition_snippets,
  )
}

output "interfaces" {
  value = local.tap_interfaces
}