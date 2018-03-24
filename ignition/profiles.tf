resource "matchbox_profile" "ns" {
  name   = "ns"
  container_linux_config = "${file("./ignition/ns.yaml.tmpl")}"
}

resource "matchbox_profile" "gateway" {
  name   = "gateway"
  container_linux_config = "${file("./ignition/gateway.yaml.tmpl")}"
}
