##
## Ignition renderer for PXE boot CoreOS VMs
##
data "ct_config" "ign" {
  for_each = var.ignition_params

  content  = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict   = true
  snippets = each.value.templates
}

resource "matchbox_profile" "ign" {
  for_each = var.ignition_params

  name         = each.key
  kernel       = each.value.kernel_image
  initrd       = each.value.initrd_images
  args         = each.value.kernel_params
  raw_ignition = data.ct_config.ign[each.key].rendered
}

resource "matchbox_group" "ign" {
  for_each = var.ignition_params

  profile = matchbox_profile.ign[each.key].name
  name    = each.key
  selector = {
    mac = each.value.selector.mac
  }
}