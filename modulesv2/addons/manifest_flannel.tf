##
## CNI (flannel) addon manifest
##
resource "matchbox_profile" "manifest-flannel" {
  name           = "flannel"
  generic_config = "{{.config}}"
}

resource "matchbox_group" "manifest-flannel" {
  name    = matchbox_profile.manifest-flannel.name
  profile = matchbox_profile.manifest-flannel.name
  selector = {
    manifest = matchbox_profile.manifest-flannel.name
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