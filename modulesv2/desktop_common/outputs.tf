output "desktop_params" {
  value = {
    for k in keys(var.desktop_hosts) :
    k => {
      hostname           = k
      user               = var.user
      uid                = 10000
      password_hash      = var.password_hash
      timezone           = var.timezone
      ssh_authorized_key = ""
      hosts              = var.desktop_hosts
      host_disks         = var.desktop_hosts[k].disk
      networks           = var.networks
      mtu                = var.mtu

      vlans = [
        for k in keys(var.networks) :
        k
        if lookup(var.networks[k], "id", null) != null
      ]

      tls_internal_ca   = replace(var.internal_ca_cert_pem, "\n", "\\n")
      internal_tls_path = "/etc/pki/ca-trust/source/anchors"
    }
  }
}