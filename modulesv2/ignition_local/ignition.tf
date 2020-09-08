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

resource "matchbox_profile" "ign" {
  for_each = var.ignition_params

  name         = each.key
  raw_ignition = data.ct_config.ign[each.key].rendered
}

resource "matchbox_group" "ign" {
  for_each = var.ignition_params

  profile = matchbox_profile.ign[each.key].name
  name    = each.key
  selector = {
    ign = each.key
  }
}