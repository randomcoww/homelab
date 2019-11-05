resource "matchbox_profile" "ign-profile" {
  name                   = "ign"
  container_linux_config = "{{.config}}"
  kernel                 = "/coreos_production_pxe.vmlinuz"
  initrd = [
    "/coreos_production_pxe_image.cpio.gz",
  ]
  args = [
    "coreos.config.url=http://${var.services.renderer.vip}:${var.services.renderer.ports.http}/ignition?mac=$${mac:hexhyp}",
    "coreos.first_boot=1",
    "console=hvc0",
    "elevator=noop"
  ]
}