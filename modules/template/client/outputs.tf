locals {
  params = {
    users            = var.users
    services         = var.services
    local_timezone   = var.local_timezone
    container_images = var.container_images
    udev_steam_input = data.http.udev-60-steam-input.body
    udev_steam_vr    = data.http.udev-60-steam-vr.body
  }
}

output "ignition" {
  value = {
    for host, params in var.hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition/*") :
      templatefile(f, merge(local.params, {
        p = params
      }))
    ]
  }
}