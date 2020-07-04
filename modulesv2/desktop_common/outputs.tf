output "templates" {
  value = {
    for host, params in var.hosts :
    host => [
      for template in var.templates :
      templatefile(template, {
        p                = params
        user             = var.user
        desktop_user     = var.desktop_user
        desktop_uid      = 10000
        desktop_password = var.desktop_password
        domains          = var.domains
        mtu              = var.mtu
        udev_steam_input = data.http.udev-60-steam-input.body
        udev_steam_vr    = data.http.udev-60-steam-vr.body
      })
    ]
  }
}