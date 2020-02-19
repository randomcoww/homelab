##
## provisioner ignition renderer
##
resource "matchbox_group" "ign-test" {
  for_each = var.test_params

  profile = matchbox_profile.profile-flatcar-autologin.name
  name    = each.key
  selector = {
    mac = each.value.host_network.int.mac
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/ignition/test.ign.tmpl", each.value)
  }
}