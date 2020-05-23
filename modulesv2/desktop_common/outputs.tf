output "templates" {
  value = {
    for k in keys(var.desktop_hosts) :
    k => [
      for template in var.desktop_templates :
      templatefile(template, {
        hostname   = k
        user       = var.user
        uid        = 10000
        password   = var.password
        timezone   = var.timezone
        hosts      = var.desktop_hosts
        host_disks = var.desktop_hosts[k].disk
        networks   = var.networks
        mtu        = var.mtu

        vlans = [
          for k in keys(var.networks) :
          k
          if lookup(var.networks[k], "id", null) != null
        ]

        tls_internal_ca   = replace(var.internal_ca_cert_pem, "\n", "\\n")
        internal_tls_path = "/etc/pki/ca-trust/source/anchors"
      })
    ]
  }
}