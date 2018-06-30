##
## kube controller kickstart renderer
##
resource "matchbox_profile" "manifest_provisioner" {
  name           = "manifest_provisioner"
  generic_config = "${file("./manifest/provisioner.yaml.tmpl")}"
}

##
## kickstart
##
resource "matchbox_group" "manifest_provisioner" {
  name    = "manifest_provisioner"
  profile = "${matchbox_profile.manifest_provisioner.name}"

  selector {
    manifest = "provisioner"
  }

  metadata {
    domain_name      = "${var.domain_name}"

    keepalived_image = "${var.keepalived_image}"
    nftables_image   = "${var.nftables_image}"
    kea_image        = "${var.kea_image}"
    tftpd_image      = "${var.tftpd_image}"
    matchbox_image   = "${var.matchbox_image}"

    matchbox_http_port = "${var.matchbox_http_port}"
    matchbox_rpc_port  = "${var.matchbox_rpc_port}"
    dhcp_relay_port    = "${var.dhcp_relay_port}"

    controller_vip = "${var.controller_vip}"
    nfs_vip        = "${var.nfs_vip}"
    matchbox_vip   = "${var.matchbox_vip}"
    store_gateway_vip = "${var.store_gateway_vip}"
    lan_gateway_vip = "${var.lan_gateway_vip}"
    dns_vip        = "${var.dns_vip}"
    backup_dns_ip  = "${var.backup_dns_ip}"

    store_netmask  = "${var.store_netmask}"
    store_if       = "eth1"
    lan_netmask    = "${var.lan_netmask}"
    lan_if         = "eth0"
    wan_if         = "eth2"

    lan_ip_range        = "${var.lan_ip_range}"
    lan_dhcp_ip_range   = "${var.lan_dhcp_ip_range}"
    store_ip_range      = "${var.store_ip_range}"
    store_dhcp_ip_range = "${var.store_dhcp_ip_range}"
    metallb_ip_range    = "${var.metallb_ip_range}"

    certs_path          = "${var.certs_path}"
    kea_path            = "/var/lib/kea"
    kea_mount_path      = "${var.base_mount_path}/kea"
    matchbox_path       = "/var/lib/matchbox"
    matchbox_mount_path = "${var.base_mount_path}/matchbox"
  }
}
