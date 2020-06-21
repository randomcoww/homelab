output "templates" {
  value = {
    for host, params in var.hosts :
    host => [
      for template in var.templates :
      templatefile(template, {
        p                = params
        user             = var.user
        uid              = 10000
        password         = var.password
        domains          = var.domains
        mtu              = var.mtu
        udev_steam_input = data.http.udev-60-steam-input.body
        udev_steam_vr    = data.http.udev-60-steam-vr.body
      })
    ]
  }
}