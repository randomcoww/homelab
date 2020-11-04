##
## Ignition renderer for local file load
##
data "ct_config" "ign" {
  for_each = var.ignition_params

  content  = <<EOT
---
variant: fcos
version: 1.0.0
EOT
  strict   = true
  snippets = each.value.templates
}