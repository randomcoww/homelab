##
## Ignition renderer for local file load
##
data "ct_config" "ign-local" {
  for_each = var.local_ignition_params

  content = templatefile(each.value.templates[0], each.value)
  strict  = true

  snippets = [
    for k in slice(each.value.templates, 1, length(each.value.templates) - 1) :
    templatefile(k, each.value)
  ]
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
    ign = each.value.hostname
  }
}