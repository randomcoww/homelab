

output "ignition_snippets" {
  value = [
    for f in concat(tolist(fileset(".", "${path.module}/ignition/*.yaml")), [
      "${path.root}/common_templates/ignition/base.yaml",
    ]) :
    templatefile(f, {
      user                  = var.user
      hostname              = var.hostname
      ssh_ca_authorized_key = var.ssh_ca_public_key_openssh
      udev_steam_input      = data.http.udev-60-steam-input.body
      udev_steam_vr         = data.http.udev-60-steam-vr.body
    })
  ]
}