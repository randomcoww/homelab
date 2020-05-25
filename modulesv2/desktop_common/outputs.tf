output "templates" {
  value = {
    for host, params in var.desktop_hosts :
    host => [
      for template in var.desktop_templates :
      templatefile(template, {
        hostname   = host
        user       = var.user
        uid        = 10000
        password   = var.password
        timezone   = var.timezone
        hosts      = var.desktop_hosts
        host_disks = params.disk
        networks   = var.networks
        mtu        = var.mtu

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