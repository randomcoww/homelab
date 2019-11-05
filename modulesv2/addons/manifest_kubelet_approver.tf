##
## kapprover addon manifest
##
resource "matchbox_profile" "manifest-kapprover" {
  name           = "kapprover"
  generic_config = "{{.config}}"
}

resource "matchbox_group" "manifest-kapprover" {
  name    = matchbox_profile.manifest-kapprover.name
  profile = matchbox_profile.manifest-kapprover.name
  selector = {
    manifest = matchbox_profile.manifest-kapprover.name
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/kapprover.yaml.tmpl", {
      namespace        = var.namespace
      container_images = var.container_images
    })
  }
}
