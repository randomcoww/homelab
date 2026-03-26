output "ignition_snippets" {
  value = concat(
    local.ignition_snippets,
  )
}