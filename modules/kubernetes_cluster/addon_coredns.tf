##
## external dns addon manifest
##
resource "matchbox_profile" "addon_coredns" {
  name           = "coredns"
  generic_config = "${file("${path.module}/templates/addon/coredns.yaml.tmpl")}"
}

resource "matchbox_group" "addon_coredns" {
  name    = "${matchbox_profile.addon_coredns.name}"
  profile = "${matchbox_profile.addon_coredns.name}"

  selector {
    addon = "${matchbox_profile.addon_coredns.name}"
  }

  metadata {
    coredns_image      = "${var.coredns_image}"
    external_dns_image = "${var.external_dns_image}"
    etcd_image         = "${var.etcd_image}"
    recursive_dns_vip  = "${var.recursive_dns_vip}"
    internal_dns_vip   = "${var.internal_dns_vip}"
    cluster_dns_ip     = "${var.cluster_dns_ip}"
    cluster_domain     = "${var.cluster_domain}"
    internal_domain    = "${var.internal_domain}"
    namespace          = "kube-system"
  }
}
