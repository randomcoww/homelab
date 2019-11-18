##
## controller ignition renderer
##
resource "matchbox_group" "ign-controller" {
  for_each = var.controller_params

  profile = matchbox_profile.ign-profile.name
  name    = each.key
  selector = {
    mac = each.value.host_network.int.mac
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/ignition/controller.ign.tmpl", each.value)
  }
}