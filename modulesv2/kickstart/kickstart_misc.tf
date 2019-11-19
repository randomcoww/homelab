##
## LiveOS base template renderer
##
resource "matchbox_group" "ks-misc" {
  for_each = {
    zfs = "${path.module}/../../templates/kickstart/zfs.ks.tmpl"
    nvidia = "${path.module}/../../templates/kickstart/nvidia.ks.tmpl"
  }

  profile = matchbox_profile.generic-profile.name
  name    = each.key
  selector = {
    ks = each.key
  }
  metadata = {
    config = templatefile(each.value, {
    })
  }
}