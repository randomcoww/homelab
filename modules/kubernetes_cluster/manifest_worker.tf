##
## kube controller manifest renderer
##
resource "matchbox_profile" "manifest_worker" {
  name           = "worker"
  generic_config = "${file("${path.module}/templates/manifest/worker.yaml.tmpl")}"
}

resource "matchbox_group" "manifest_worker" {
  name    = "${matchbox_profile.manifest_worker.name}"
  profile = "${matchbox_profile.manifest_worker.name}"

  selector {
    manifest = "${matchbox_profile.manifest_worker.name}"
  }

  metadata {
    kube_proxy_image  = "${var.kube_proxy_image}"
    flannel_image     = "${var.flannel_image}"
    cni_plugins_image = "${var.cni_plugins_image}"
    kubelet_path      = "${var.kubelet_path}"
  }
}
