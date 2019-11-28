##
## Internal TLS for use with ingress
##
resource "matchbox_group" "manifest-secret" {
  for_each = var.secrets

  profile = matchbox_profile.generic-profile.name
  name    = each.key
  selector = {
    secret = each.key
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/secret.yaml.tmpl", {
      name      = each.key
      namespace = each.value.namespace
      data      = each.value.data
      type      = each.value.type
    })
  }
}