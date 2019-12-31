##
## worker ignition renderer
##
resource "matchbox_group" "ign-worker" {
  for_each = var.worker_params

  profile = matchbox_profile.profile-flatcar.name
  name    = each.key
  selector = {
    mac = each.value.host_network.int.mac
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/ignition/worker.ign.tmpl", each.value)
  }
}