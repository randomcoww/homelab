##
## metallb addon manifest
## this is only the configMap and also requires
## https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
##
resource "matchbox_group" "manifest-metallb" {
  profile = matchbox_profile.generic-profile.name
  name    = "metallb"
  selector = {
    manifest = "metallb"
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/metallb.yaml.tmpl", {
      loadbalancer_pools = var.loadbalancer_pools
    })
  }
}