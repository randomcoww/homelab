##
## kube proxy addon manifest
##
resource "matchbox_profile" "manifest-kube-proxy" {
  name           = "kube-proxy"
  generic_config = "{{.config}}"
}

resource "matchbox_group" "manifest-kube-proxy" {
  name    = matchbox_profile.manifest-kube-proxy.name
  profile = matchbox_profile.manifest-kube-proxy.name
  selector = {
    manifest = matchbox_profile.manifest-kube-proxy.name
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/kube_proxy.yaml.tmpl", {
      namespace        = var.namespace
      apiserver_vip    = var.apiserver_vip
      services         = var.services
      networks         = var.networks
      container_images = var.container_images
    })
  }
}
