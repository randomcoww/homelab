##
## KVM (HW) kickstart renderer
##

resource "matchbox_profile" "ks-kvm" {
  name           = "kvm"
  generic_config = file("${path.module}/../../templates/kickstart/kvm.ks.tmpl")
}

resource "matchbox_group" "ks-kvm" {
  for_each = var.kvm_hosts

  profile = matchbox_profile.ks-kvm.name
  name    = each.key
  selector = {
    ks = each.key
  }
  metadata = {
    hostname           = each.key
    user               = var.user
    password           = var.password
    ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
    networkd = chomp(templatefile("${path.module}/../../templates/misc/networkd.tmpl", {
      file_path = "/etc/systemd/network"
      priority  = 20
      config    = each.value.network
      vlans = [
        "store",
        "lan",
        "sync",
        "wan"
      ]
      host_tap_vlan = "store"
      host_tap_if   = "host-tap"
      mtu           = var.mtu
      networks      = var.networks
    }))
    certs_path           = "/etc/ssl/certs"
    matchbox_url         = "https://github.com/poseidon/matchbox/releases/download/v0.8.0/matchbox-v0.8.0-linux-amd64.tar.gz"
    matchbox_data_path   = "/var/lib/matchbox/data"
    matchbox_assets_path = "/var/lib/matchbox/assets"
    tls_matchbox_ca      = chomp(tls_self_signed_cert.matchbox-ca.cert_pem)
    tls_matchbox         = chomp(tls_locally_signed_cert.matchbox[each.key].cert_pem)
    tls_matchbox_key     = chomp(tls_private_key.matchbox[each.key].private_key_pem)

    int_if        = var.networks.int.if
    int_dummy_if  = "int-dummy"
    int_tap_if    = "int-tap"
    int_tap_ip    = var.networks.int.ip
    int_cidr      = var.networks.int.cidr
    int_dhcp_pool = var.networks.int.dhcp_pool

    matchbox_http_port       = var.service_ports.renderer_http
    matchbox_rpc_port        = var.service_ports.renderer_rpc
    container_linux_base_url = "https://beta.release.core-os.net/amd64-usr/current"
  }
}