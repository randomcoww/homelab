

output "ignition_snippets" {
  value = concat(
    local.common_ignition_snippets,
    local.module_ignition_snippets,
  )
}