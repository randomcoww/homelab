default_user    = "core"

## images
container_linux_version = "1800.2.0"
fedora_live_version = "4.15.14-300.fc27.x86_64"
hyperkube_image = "gcr.io/google_containers/hyperkube:v1.10.5"
keepalived_image = "randomcoww/keepalived:20180626.01"
kube_apiserver_image = "gcr.io/google_containers/kube-apiserver:v1.10.5"
kube_controller_manager_image = "gcr.io/google_containers/kube-controller-manager:v1.10.5"
kube_scheduler_image = "gcr.io/google_containers/kube-scheduler:v1.10.5"
kube_proxy_image = "gcr.io/google_containers/kube-proxy:v1.10.5"
etcd_image = "quay.io/coreos/etcd:v3.3"
flannel_image = "quay.io/coreos/flannel:v0.10.0-amd64"
nftables_image = "randomcoww/nftables:20180412.01"
kea_image = "randomcoww/kea:1.4.0"
tftpd_image = "randomcoww/tftpd_ipxe:20180222.02"
matchbox_image = "quay.io/coreos/matchbox:latest"

## kubernetes
cluster_cidr    = "10.244.0.0/16"
cluster_dns_ip  = "10.96.0.10"
cluster_service_ip = "10.96.0.1"
cluster_ip_range = "10.96.0.0/12"
cluster_name    = "kube_cluster"
cluster_domain  = "cluster.local"
kubernetes_path = "/var/lib/kubernetes"
etcd_initial_cluster = "controller-0=https://192.168.126.219:2380"
etcd_cluster_token = "etcd-default"

## ports
etcd_client_port = "52379"
apiserver_secure_port = "56443"
matchbox_rpc_port = "58081"
matchbox_http_port = "58080"

## ip
controller_vip = "192.168.126.245"
gateway_vip    = "192.168.126.240"
nfs_vip        = "192.168.126.251"
matchbox_vip   = "192.168.126.242"
dns_vip        = "192.168.127.254"
lan_netmask    = "23"
store_netmask  = "23"
backup_dns_ip  = "9.9.9.9"

## ip ranges
lan_ip_range     = "192.168.62.0/23"
store_ip_range   = "192.168.126.0/23"
lan_dhcp_ip_range   = "192.168.62.64/26"
store_dhcp_ip_range = "192.168.126.64/26"
metallb_ip_range    = "192.168.127.128/25"
