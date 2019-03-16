##
## provisioner ignition renderer
##
resource "matchbox_profile" "ignition_provisioner" {
  name                   = "host_provisioner"
  container_linux_config = "${file("${path.module}/templates/ignition/provisioner.ign.tmpl")}"
}

locals {
  kea_ha_peers_template = {
    name = "%s"
    role = "%s"
    url  = "http://%s:${var.kea_peer_port}/"
  }

  syncthing_folder_devices_template = <<EOF
<device id="%s"></device>
EOF

  syncthing_devices_template = <<EOF
<device id="%s" compression="always" skipIntroductionRemovals="true"><address>%s:%s</address><allowedNetwork>%s</allowedNetwork></device>
EOF
}

resource "matchbox_group" "ignition_provisioner" {
  count = "${length(var.provisioner_hosts)}"

  name    = "ignition_${var.provisioner_hosts[count.index]}"
  profile = "${matchbox_profile.ignition_provisioner.name}"

  selector {
    ign = "${var.provisioner_hosts[count.index]}"
  }

  metadata {
    hostname           = "${var.provisioner_hosts[count.index]}"
    hyperkube_image    = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
    default_user       = "${var.default_user}"

    keepalived_image = "${var.keepalived_image}"
    unbound_image    = "${var.unbound_image}"
    nftables_image   = "${var.nftables_image}"
    kea_image        = "${var.kea_image}"
    tftpd_image      = "${var.tftpd_image}"
    matchbox_image   = "${var.matchbox_image}"
    syncthing_image  = "${var.syncthing_image}"

    matchbox_http_port  = "${var.matchbox_http_port}"
    matchbox_rpc_port   = "${var.matchbox_rpc_port}"
    kea_peer_port       = "${var.kea_peer_port}"
    syncthing_peer_port = "${var.syncthing_peer_port}"

    matchbox_vip      = "${var.matchbox_vip}"
    store_gateway_vip = "${var.store_gateway_vip}"
    lan_gateway_vip   = "${var.lan_gateway_vip}"
    dns_vip           = "${var.dns_vip}"
    backup_dns_ip     = "${var.backup_dns_ip}"

    lan_ip        = "${var.provisioner_lan_ips[count.index]}"
    lan_if        = "${var.provisioner_lan_if}"
    lan_netmask   = "${var.lan_netmask}"
    store_ip      = "${var.provisioner_store_ips[count.index]}"
    store_if      = "${var.provisioner_store_if}"
    store_netmask = "${var.store_netmask}"
    sync_ip       = "${var.provisioner_sync_ips[count.index]}"
    sync_if       = "${var.provisioner_sync_if}"
    sync_netmask  = "${var.sync_netmask}"
    wan_if        = "${var.provisioner_wan_if}"
    vwan_if       = "${var.provisioner_vwan_if}"
    mtu           = "${var.mtu}"

    domain_name = "${var.domain_name}"

    lan_ip_range        = "${var.lan_ip_range}"
    lan_dhcp_ip_range   = "${var.lan_dhcp_ip_range}"
    store_ip_range      = "${var.store_ip_range}"
    store_dhcp_ip_range = "${var.store_dhcp_ip_range}"

    kubelet_path  = "${var.kubelet_path}"
    certs_path    = "${var.certs_path}"
    kea_path      = "${var.kea_path}"
    matchbox_path = "${var.matchbox_path}"

    kea_ha_peers = "${join(",", formatlist(
      "${jsonencode(local.kea_ha_peers_template)}",
      "${var.provisioner_hosts}",
      "${var.kea_ha_roles}",
      "${var.provisioner_store_ips}"
    ))}"

    syncthing_folder_devices = "${join("", formatlist(
      "${chomp(local.syncthing_folder_devices_template)}",
      "${data.syncthing_device.syncthing.*.device_id}"
    ))}"

    syncthing_devices = "${join("", formatlist(
      "${chomp(local.syncthing_devices_template)}",
      "${data.syncthing_device.syncthing.*.device_id}",
      "${var.provisioner_store_ips}",
      "${var.syncthing_peer_port}",
      "${var.store_ip_range}"
    ))}"

    tls_ca            = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    tls_matchbox      = "${replace(element(tls_locally_signed_cert.matchbox.*.cert_pem, count.index), "\n", "\\n")}"
    tls_matchbox_key  = "${replace(element(tls_private_key.matchbox.*.private_key_pem, count.index), "\n", "\\n")}"
    tls_syncthing     = "${replace(element(tls_locally_signed_cert.syncthing.*.cert_pem, count.index), "\n", "\\n")}"
    tls_syncthing_key = "${replace(element(tls_private_key.syncthing.*.private_key_pem, count.index), "\n", "\\n")}"
  }
}
