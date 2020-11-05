locals {
  params = {
    client_password  = var.client_password
    domains          = var.domains
    udev_steam_input = data.http.udev-60-steam-input.body
    udev_steam_vr    = data.http.udev-60-steam-vr.body
    wireguard_config = var.wireguard_config
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