# Matchbox configs for PXE environment with matchbox renderer
module "provisioner" {
    source = "./module"

    ## user (default container linux)
    default_user = "core"

    ## DHCP domain
    domain_name = "host.internal"

    provisioner_hosts = ["provisioner-0"]
    provisioner_lan_ips = ["192.168.62.217"]
    provisioner_store_ips = ["192.168.126.217"]
    provisioner_lan_if = "eth0"
    provisioner_store_if = "eth1"
    provisioner_wan_if = "eth2"

    ## images
    container_linux_version = "1828.3.0"
    hyperkube_image = "gcr.io/google_containers/hyperkube:v1.11.0"
    keepalived_image = "randomcoww/keepalived:20180716.01"
    nftables_image = "randomcoww/nftables:20180628.01"
    kea_image = "randomcoww/kea:1.4.0"
    tftpd_image = "randomcoww/tftpd_ipxe:20180626.02"
    matchbox_image = "quay.io/coreos/matchbox:latest"

    ## ports
    matchbox_http_port = "58080"
    matchbox_rpc_port  = "58081"

    ## vip
    controller_vip    = "192.168.126.245"
    store_gateway_vip = "192.168.126.240"
    lan_gateway_vip   = "192.168.62.240"
    dns_vip           = "192.168.127.254"
    matchbox_vip      = "192.168.126.242"
    nfs_vip           = "192.168.126.251"
    backup_dns_ip     = "9.9.9.9"

    ## ip ranges
    lan_netmask = "23"
    store_netmask = "23"
    lan_ip_range     = "192.168.62.0/23"
    store_ip_range   = "192.168.126.0/23"
    lan_dhcp_ip_range   = "192.168.62.64/26"
    store_dhcp_ip_range = "192.168.126.64/26"
    metallb_ip_range = "192.168.127.128/25"

    ## persist data on host
    kea_mount_path = "/data/pv/kea"
    matchbox_mount_path = "/data/pv/matchbox"

    ## github provisioner url
    remote_provision_url = "https://raw.githubusercontent.com/randomcoww/terraform/master/static"

    ## renderer provisioning access
    renderer_endpoint = "127.0.0.1:8081"
    renderer_cert_pem = "${file("../renderer/output/server.crt")}"
    renderer_private_key_pem = "${file("../renderer/output/server.key")}"
    renderer_ca_pem = "${file("../renderer/output/ca.crt")}"
}
