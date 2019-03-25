##
## external dns addon manifest
##
resource "matchbox_profile" "addon_external_dns" {
  name           = "external-dns"
  generic_config = "${file("${path.module}/templates/addon/external_dns.yaml.tmpl")}"
}

resource "matchbox_group" "addon_external_dns" {
  name    = "${matchbox_profile.addon_external_dns.name}"
  profile = "${matchbox_profile.addon_external_dns.name}"

  selector {
    addon = "${matchbox_profile.addon_external_dns.name}"
  }

  metadata {
    coredns_image           = "${var.coredns_image}"
    external_dns_image      = "${var.external_dns_image}"
    etcd_endpoints          = "${join(",", formatlist("https://%s:${var.etcd_client_port}", "${var.controller_ips}"))}"
    corefile_etcd_endpoints = "${join(" ", formatlist("https://%s:${var.etcd_client_port}", "${var.controller_ips}"))}"
    kubelet_path            = "${var.kubelet_path}"
    internal_dns_vip        = "${var.internal_dns_vip}"
    namespace               = "kube-system"
  }
}
