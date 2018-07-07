default_user = "core"
domain_name  = "host.internal"

## hosts
provisioner_hosts = ["provisioner-0"]
provisioner_lan_ips = ["192.168.62.217"]
provisioner_store_ips = ["192.168.126.217"]

controller_hosts = ["controller-0", "controller-1", "controller-2"]
controller_ips = ["192.168.126.219", "192.168.126.220", "192.168.126.221"]
controller_macs = ["52-54-00-1a-61-0a", "52-54-00-1a-61-0b", "52-54-00-1a-61-0c"]

worker_hosts = ["worker-0", "worker-1"]
worker_macs = ["52-54-00-1a-61-1a", "52-54-00-1a-61-1b"]

store_hosts = ["store-0"]
store_lan_ips = ["192.168.62.251"]
store_store_ips = ["192.168.126.251"]

## images
container_linux_version = "1800.2.0"
fedora_live_version = "4.15.14-300.fc27.x86_64"
hyperkube_image = "gcr.io/google_containers/hyperkube:v1.11.0"
keepalived_image = "randomcoww/keepalived:20180626.01"
kube_apiserver_image = "gcr.io/google_containers/kube-apiserver:v1.11.0"
kube_controller_manager_image = "gcr.io/google_containers/kube-controller-manager:v1.11.0"
kube_scheduler_image = "gcr.io/google_containers/kube-scheduler:v1.11.0"
kube_proxy_image = "gcr.io/google_containers/kube-proxy:v1.11.0"
etcd_image = "quay.io/coreos/etcd:v3.3"
flannel_image = "quay.io/coreos/flannel:v0.10.0-amd64"
nftables_image = "randomcoww/nftables:20180628.01"
kea_image = "randomcoww/kea:1.4.0"
tftpd_image = "randomcoww/tftpd_ipxe:20180626.02"
matchbox_image = "quay.io/coreos/matchbox:latest"

## kubernetes
cluster_cidr    = "10.244.0.0/16"
cluster_dns_ip  = "10.96.0.10"
cluster_service_ip = "10.96.0.1"
cluster_ip_range = "10.96.0.0/12"
cluster_name    = "kube_cluster"
cluster_domain  = "cluster.local"
kubernetes_path = "/var/lib/kubernetes"
etcd_cluster_token = "etcd-default"

## ports
etcd_client_port = "52379"
etcd_peer_port = "52380"
apiserver_secure_port = "56443"
matchbox_rpc_port = "58081"
matchbox_http_port = "58080"
dhcp_relay_port = "8080"

## ip
controller_vip = "192.168.126.245"
nfs_vip        = "192.168.126.251"
matchbox_vip   = "192.168.126.242"
dns_vip        = "192.168.127.254"
store_gateway_vip = "192.168.126.240"
lan_gateway_vip = "192.168.62.240"
backup_dns_ip  = "9.9.9.9"

lan_netmask    = "23"
store_netmask  = "23"

remote_provision_url = "https://raw.githubusercontent.com/randomcoww/terraform/master/static"

## ip ranges
lan_ip_range     = "192.168.62.0/23"
store_ip_range   = "192.168.126.0/23"
lan_dhcp_ip_range   = "192.168.62.64/26"
store_dhcp_ip_range = "192.168.126.64/26"
metallb_ip_range    = "192.168.127.128/25"

## general paths
certs_path = "/etc/ssl/certs"
base_mount_path = "/data/pv"
