##
## CNI (flannel) addon manifest
##
resource "matchbox_group" "manifest-flannel" {
  profile = matchbox_profile.manifest-profile.name
  name    = "flannel"
  selector = {
    manifest = "flannel"
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/flannel.yaml.tmpl", {
      namespace        = var.namespace
      container_images = var.container_images
      services         = var.services
      networks         = var.networks
      domains          = var.domains
    })
  }
}