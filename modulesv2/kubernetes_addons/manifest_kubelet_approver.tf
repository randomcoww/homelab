##
## kapprover addon manifest
##
resource "matchbox_group" "manifest-kapprover" {
  profile = matchbox_profile.generic-profile.name
  name    = "kapprover"
  selector = {
    manifest = "kapprover"
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/kapprover.yaml.tmpl", {
      namespace        = var.namespace
      container_images = var.container_images
    })
  }
}
