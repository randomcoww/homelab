##
## CNI (flannel) addon manifest
##
resource "matchbox_profile" "addon_flannel" {
  name           = "flannel"
  generic_config = "${file("${path.module}/templates/addon/flannel.yaml.tmpl")}"
}

resource "matchbox_group" "addon_flannel" {
  name    = "${matchbox_profile.addon_flannel.name}"
  profile = "${matchbox_profile.addon_flannel.name}"

  selector {
    addon = "${matchbox_profile.addon_flannel.name}"
  }

  metadata {
    flannel_image     = "${var.flannel_image}"
    cni_plugins_image = "${var.cni_plugins_image}"

    cluster_cidr = "${var.cluster_cidr}"
  }
}
