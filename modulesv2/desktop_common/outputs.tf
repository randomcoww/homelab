output "templates" {
  value = {
    for host, params in var.desktop_hosts :
    host => [
      for template in var.desktop_templates :
      templatefile(template, {
        hostname         = params.hostname
        user             = var.user
        uid              = 10000
        password         = var.password
        timezone         = var.timezone
        host_disks       = params.disk
        networks         = var.networks
        domains          = var.domains
        host_network     = params.host_network
        mtu              = var.mtu
        udev_steam_input = data.http.udev-60-steam-input.body
        udev_steam_vr    = data.http.udev-60-steam-vr.body

        vlans = [
          for k, v in var.networks :
          k
          if lookup(v, "id", null) != null
        ]

        tls_internal_ca   = replace(var.internal_ca_cert_pem, "\n", "\\n")
        internal_tls_path = "/etc/pki/ca-trust/source/anchors"
      })
    ]
  }
}