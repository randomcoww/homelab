resource "matchbox_profile" "ns" {
  name   = "ns"
  container_linux_config = "${file("./ignition/ns.yaml.tmpl")}"
}

resource "matchbox_profile" "gateway" {
  name   = "gateway"
  container_linux_config = "${file("./ignition/gateway.yaml.tmpl")}"
}

resource "matchbox_profile" "controller" {
  name   = "controller"
  container_linux_config = "${file("./ignition/controller.yaml.tmpl")}",
  kernel = "/assets/coreos/${var.container_linux_version}/coreos_production_pxe.vmlinuz"
  initrd = [
    "/assets/coreos/${var.container_linux_version}/coreos_production_pxe_image.cpio.gz"
  ]
  args = [
    "coreos.config.url=${var.matchbox_http_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.first_boot=yes",
    "console=hvc0",
    "coreos.autologin"
  ]
}

resource "matchbox_profile" "vmhost_base" {
  name   = "vmhost_base"
  generic_config = "${file("./kickstart/vmhost.ks.tmpl")}"
}

# generic cloud-config - not container linux formatted
resource "matchbox_profile" "vmhost" {
  name   = "vmhost"
  generic_config = "${file("./cloud/vmhost.yaml.tmpl")}"
}
