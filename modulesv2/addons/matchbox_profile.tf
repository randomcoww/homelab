resource "matchbox_profile" "manifest-profile" {
  name           = "manifest"
  generic_config = "{{.config}}"
}