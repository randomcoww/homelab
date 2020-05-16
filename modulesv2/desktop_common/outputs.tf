output "desktop_params" {
  value = {
    for k in keys(var.desktop_hosts) :
    k => {
      hostname           = k
      user               = var.user
      password           = var.password
      timezone           = var.timezone
      ssh_authorized_key = ""
      uid                = 10000
      hosts              = var.desktop_hosts
      host_disks         = var.desktop_hosts[k].disk
      networks           = var.networks
      mtu                = var.mtu

      vlans = [
        for k in keys(var.networks) :
        k
        if lookup(var.networks[k], "id", null) != null
      ]

      tls_internal_ca   = chomp(var.internal_ca_cert_pem)
      internal_tls_path = "/usr/share/pki/ca-trust-source/anchors"
    }
  }
}