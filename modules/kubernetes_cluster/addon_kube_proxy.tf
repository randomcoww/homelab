##
## kube proxy addon manifest
##
resource "matchbox_profile" "addon_kube_proxy" {
  name           = "kube-proxy"
  generic_config = "${file("${path.module}/templates/addon/kube_proxy.yaml.tmpl")}"
}

resource "matchbox_group" "addon_kube_proxy" {
  name    = "${matchbox_profile.addon_kube_proxy.name}"
  profile = "${matchbox_profile.addon_kube_proxy.name}"

  selector {
    addon = "${matchbox_profile.addon_kube_proxy.name}"
  }

  metadata {
    kube_proxy_image = "${var.kube_proxy_image}"

    controller_vip        = "${var.controller_vip}"
    apiserver_secure_port = "${var.apiserver_secure_port}"

    cluster_name = "${var.cluster_name}"
    cluster_cidr = "${var.cluster_cidr}"
  }
}
