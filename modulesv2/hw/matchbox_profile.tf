resource "matchbox_profile" "generic-profile" {
  name           = "generic"
  generic_config = "{{.config}}"
}