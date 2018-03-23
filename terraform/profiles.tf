resource "matchbox_profile" "ns" {
  name   = "ns"
  container_linux_config = "${file("./ignition/ns.yaml.tmpl")}"
}
