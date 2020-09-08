##
## Matchbox renderer for generic
##
resource "matchbox_profile" "generic" {
  for_each = var.generic_params

  name           = each.key
  generic_config = "{{.config}}"
}

resource "matchbox_group" "generic" {
  for_each = var.generic_params

  profile = matchbox_profile.generic[each.key].name
  name    = each.key
  selector = {
    manifest = each.key
  }
  metadata = {
    config = each.value
  }
}