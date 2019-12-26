##
## kubernetes and external dns addon manifest
##
resource "matchbox_group" "manifest-coredns" {
  profile = matchbox_profile.generic-profile.name
  name    = "coredns"
  selector = {
    manifest = "coredns"
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/coredns.yaml.tmpl", {
      namespace        = "kube-system"
      container_images = var.container_images
      services         = var.services
      domains          = var.domains
    })
  }
}