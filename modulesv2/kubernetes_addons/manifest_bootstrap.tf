##
## admin and worker bootstrap clusterroles
##
resource "matchbox_group" "manifest-bootstrap" {
  profile = matchbox_profile.generic-profile.name
  name    = "bootstrap"
  selector = {
    manifest = "bootstrap"
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/bootstrap.yaml.tmpl", {
    })
  }
}