##
## external dns addon manifest
##
resource "matchbox_profile" "manifest-coredns" {
  name           = "coredns"
  generic_config = "{{.config}}"
}

resource "matchbox_group" "manifest-coredns" {
  name    = matchbox_profile.manifest-coredns.name
  profile = matchbox_profile.manifest-coredns.name
  selector = {
    manifest = matchbox_profile.manifest-coredns.name
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/coredns.yaml.tmpl", {
      namespace        = var.namespace
      container_images = var.container_images
      services         = var.services
      domains          = var.domains
    })
  }
}