output "desktop_params" {
  value = {
    for k in keys(var.desktop_hosts) :
    k => {
      hostname = k
      user     = var.user
      password = var.password
      timezone = var.local_timezone
      uid      = 10000
      hosts    = var.desktop_hosts
      networks = var.networks
      mtu      = var.mtu

      vlans = [
        for k in keys(var.networks) :
        k
        if lookup(var.networks[k], "id", null) != null
      ]

      tls_internal_ca      = chomp(var.internal_ca_cert_pem)
      internal_tls_path    = "/usr/share/pki/ca-trust-source/anchors"
      persistent_home_path = "/localhome"
      persistent_home_dev  = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_250GB_S465NB0K598517N-part1"
    }
  }
}