resource "matchbox_profile" "ns" {
  name   = "ns"
  container_linux_config = "${file("./ignition/ns.yaml.tmpl")}"
}

resource "matchbox_profile" "gateway" {
  name   = "gateway"
  container_linux_config = "${file("./ignition/gateway.yaml.tmpl")}"
}

resource "matchbox_profile" "vmhost" {
  name   = "vmhost"
  generic_config = "${file("./kickstart/vmhost.ks.tmpl")}"
}
