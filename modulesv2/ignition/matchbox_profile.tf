resource "matchbox_profile" "ign-profile" {
  name                   = "ign"
  container_linux_config = "{{.config}}"
  kernel                 = "/assets/coreos_production_pxe.vmlinuz"
  initrd = [
    "/assets/coreos_production_pxe_image.cpio.gz",
  ]
  args = [
    "ignition.config.url=http://${var.services.renderer.vip}:${var.services.renderer.ports.http}/ignition?mac=$${mac:hexhyp}",
    "coreos.first_boot=1",
    "console=hvc0"
  ]
}