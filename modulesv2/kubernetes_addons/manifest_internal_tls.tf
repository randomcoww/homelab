##
## Internal TLS for use with ingress
##
resource "matchbox_group" "manifest-internal-tls" {
  profile = matchbox_profile.generic-profile.name
  name    = "internal-tls"
  selector = {
    manifest = "internal-tls"
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/manifest/internal_tls.yaml.tmpl", {
      tls_internal     = replace(base64encode(chomp(var.internal_cert_pem)), "\n", "")
      tls_internal_key = replace(base64encode(chomp(var.internal_private_key_pem)), "\n", "")
    })
  }
}