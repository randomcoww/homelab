resource "matchbox_profile" "profile-noop" {
  name                   = "noop"
  container_linux_config = "{{.config}}"
}