

output "ignition_snippets" {
  value = concat([
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      ssh_ca_authorized_key = var.ssh_ca_public_key_openssh
      udev_steam_input      = data.http.udev-60-steam-input.body
      udev_steam_vr         = data.http.udev-60-steam-vr.body
    })
    ], [
    templatefile("${path.root}/common_templates/ignition/base.yaml", {
      users    = [var.user]
      hostname = var.hostname
    }),
  ])
}