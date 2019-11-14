##
## kube proxy addon manifest
##
resource "matchbox_group" "manifest-kube-proxy" {
  profile = matchbox_profile.generic-profile.name
  name    = "kube-proxy"
  selector = {
    manifest = "kube-proxy"
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/kube_proxy.yaml.tmpl", {
      namespace        = var.namespace
      services         = var.services
      networks         = var.networks
      container_images = var.container_images
    })
  }
}
