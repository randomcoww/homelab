##
## Ignition renderer for local file load
##
data "ct_config" "ign-local" {
  for_each = var.local_ignition_params

  content  = <<EOT
---
variant: fcos
version: 1.0.0
EOT
  strict   = true
  snippets = each.value.templates
}

resource "matchbox_profile" "ign-local" {
  for_each = var.local_ignition_params

  name         = each.key
  raw_ignition = data.ct_config.ign-local[each.key].rendered
}

resource "matchbox_group" "ign-local" {
  for_each = var.local_ignition_params

  profile = matchbox_profile.ign-local[each.key].name
  name    = each.key
  selector = {
    ign = each.key
  }
}