resource "matchbox_profile" "ks-profile" {
  name           = "ks"
  generic_config = "{{.config}}"
}