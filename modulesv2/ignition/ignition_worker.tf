##
## worker ignition renderer
##
resource "matchbox_group" "ign-worker" {
  for_each = var.worker_params

  profile = matchbox_profile.ign-profile.name
  name    = each.key
  selector = {
    mac = each.value.host_network.int_mac
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/ignition/worker.ign.tmpl", each.value)
  }
}