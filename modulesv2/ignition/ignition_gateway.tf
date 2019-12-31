##
## provisioner ignition renderer
##
resource "matchbox_group" "ign-gateway" {
  for_each = var.gateway_params

  profile = matchbox_profile.profile-flatcar.name
  name    = each.key
  selector = {
    mac = each.value.host_network.int.mac
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/ignition/gateway.ign.tmpl", each.value)
  }
}