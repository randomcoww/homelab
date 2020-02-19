resource "matchbox_profile" "profile-flatcar-autologin" {
  name                   = "flatcar-autologin"
  container_linux_config = "{{.config}}"
  kernel                 = "/assets/flatcar_production_pxe.vmlinuz"
  initrd = [
    "/assets/flatcar_production_pxe_image.cpio.gz",
  ]
  args = [
    "ignition.config.url=http://${var.services.renderer.vip}:${var.services.renderer.ports.http}/ignition?mac=$${mac:hexhyp}",
    "flatcar.first_boot=1",
    "flatcar.autologin",
    "console=hvc0",
  ]
}