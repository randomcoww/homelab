##
## kapprover addon manifest
##
resource "matchbox_profile" "addon_kapprover" {
  name           = "kapprover"
  generic_config = "${file("${path.module}/templates/addon/kapprover.yaml.tmpl")}"
}

resource "matchbox_group" "addon_kapprover" {
  name    = "${matchbox_profile.addon_kapprover.name}"
  profile = "${matchbox_profile.addon_kapprover.name}"

  selector {
    addon = "${matchbox_profile.addon_kapprover.name}"
  }

  metadata {
    kapprover_image = "${var.kapprover_image}"
    namespace       = "kube-system"
  }
}
