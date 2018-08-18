##
## provisioner manifest renderer
##
resource "matchbox_profile" "manifest_provisioner" {
  name           = "provisioner"
  generic_config = "${file("${path.module}/templates/manifest/provisioner.yaml.tmpl")}"
}

locals {
  kea_ha_peers_template = <<EOF
{"name": "%s", "url": "http://%s:${var.kea_peer_port}/", "role": "%s", "auto-failover": true}EOF
}

resource "matchbox_group" "manifest_provisioner" {
  name    = "${matchbox_profile.manifest_provisioner.name}"
  profile = "${matchbox_profile.manifest_provisioner.name}"

  selector {
    manifest = "${matchbox_profile.manifest_provisioner.name}"
  }

  metadata {
    domain_name = "${var.domain_name}"

    keepalived_image = "${var.keepalived_image}"
    nftables_image   = "${var.nftables_image}"
    kea_image        = "${var.kea_image}"
    tftpd_image      = "${var.tftpd_image}"
    matchbox_image   = "${var.matchbox_image}"

    matchbox_http_port = "${var.matchbox_http_port}"
    matchbox_rpc_port  = "${var.matchbox_rpc_port}"
    kea_peer_port      = "${var.kea_peer_port}"

    controller_vip    = "${var.controller_vip}"
    nfs_vip           = "${var.nfs_vip}"
    matchbox_vip      = "${var.matchbox_vip}"
    store_gateway_vip = "${var.store_gateway_vip}"
    lan_gateway_vip   = "${var.lan_gateway_vip}"
    dns_vip           = "${var.dns_vip}"
    backup_dns_ip     = "${var.backup_dns_ip}"

    store_if = "${var.provisioner_store_if}"
    lan_if   = "${var.provisioner_lan_if}"
    wan_if   = "${var.provisioner_wan_if}"

    lan_ip_range        = "${var.lan_ip_range}"
    lan_dhcp_ip_range   = "${var.lan_dhcp_ip_range}"
    store_ip_range      = "${var.store_ip_range}"
    store_dhcp_ip_range = "${var.store_dhcp_ip_range}"
    metallb_ip_range    = "${var.metallb_ip_range}"

    certs_path          = "${var.certs_path}"
    kea_path            = "${var.kea_path}"
    kea_mount_path      = "${var.kea_mount_path}"
    matchbox_path       = "${var.matchbox_path}"
    matchbox_mount_path = "${var.matchbox_mount_path}"

    kea_ha_peers = "${join(",", formatlist("${local.kea_ha_peers_template}", "${var.provisioner_hosts}", "${var.provisioner_store_ips}", "${var.kea_ha_roles}"))}"
  }
}
