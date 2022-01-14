

output "ignition_snippets" {
  value = concat(
    local.module_ignition_snippets,
  )
}