##
## loki addon manifest
##
resource "matchbox_group" "manifest-loki" {
  profile = matchbox_profile.generic-profile.name
  name    = "loki"
  selector = {
    manifest = "loki"
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/loki.yaml.tmpl", {
      namespace        = "default"
      services         = var.services
      container_images = var.container_images
    })
  }
}