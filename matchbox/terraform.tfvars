matchbox_http_endpoint = "http://127.0.0.1:58080"
matchbox_rpc_endpoint = "127.0.0.1:58081"

container_linux_version = "1688.3.0"
hyperkube_image = "gcr.io/google_containers/hyperkube:v1.10.3"
default_user    = "core"

matchbox_url    = "http://192.168.126.242:58080"
cluster_cidr    = "10.200.0.0/16"
cluster_dns_ip  = "10.32.0.10"
cluster_service_ip = "10.32.0.1"

cluster_name    = "kube_cluster"
cluster_domain  = "cluster.local"

vip_matchbox    = "192.168.126.242"
vip_controller  = "192.168.126.245"
vip_gateway     = "192.168.126.240"
vip_dns         = "192.168.127.254"
