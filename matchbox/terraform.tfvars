default_user    = "core"

matchbox_http_endpoint = "http://127.0.0.1:58080"
matchbox_rpc_endpoint = "127.0.0.1:58081"
matchbox_url    = "http://192.168.126.242:58080"

container_linux_version = "1688.3.0"
hyperkube_image = "gcr.io/google_containers/hyperkube:v1.10.3"
keepalived_image = "randomcoww/keepalived:20180412.02"
kube_apiserver_image = "gcr.io/google_containers/kube-apiserver:v1.10.3"
kube_controller_manager_image = "gcr.io/google_containers/kube-controller-manager:v1.10.3"
kube_scheduler_image = "gcr.io/google_containers/kube-scheduler:v1.10.3"
kube_proxy_image = "gcr.io/google_containers/kube-proxy:v1.10.3"
etcd_image = "quay.io/coreos/etcd:v3.3"
flannel_image = "quay.io/coreos/flannel:v0.10.0-amd64"

cluster_cidr    = "10.200.0.0/16"
cluster_dns_ip  = "10.32.0.10"
cluster_service_ip = "10.32.0.1"
cluster_ip_range = "10.32.0.0/24"
cluster_name    = "kube_cluster"
cluster_domain  = "cluster.local"
kubernetes_path = "/var/lib/kubernetes"

etcd_client_port = "52379"
apiserver_secure_port = "56443"

controller_vip  = "192.168.126.245"
gateway_vip     = "192.168.126.240"
dns_vip         = "192.168.127.254"
nfs_vip         = "192.168.126.251"

lan_netmask = "23"
store_netmask = "23"

etcd_initial_cluster = "controller-0=https://192.168.126.219:2380"
etcd_cluster_token = "etcd-default"
