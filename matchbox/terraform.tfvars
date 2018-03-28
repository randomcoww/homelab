matchbox_http_endpoint = "http://haproxy.svc.internal:48080"
matchbox_rpc_endpoint = "haproxy.svc.internal:48081"

hyperkube_image = "gcr.io/google_containers/hyperkube:v1.10.0"
gateway_ip      = "192.168.126.240"
dns_ip          = "192.168.126.244"
default_user    = "core"

cluster_dns_ip = "10.3.0.10"
cluster_domain = "cluster.local"

flannel_conf = <<EOF
{
  "Network": "10.244.0.0/16",
  "Backend": {
    "Type": "vxlan"
  }
}
EOF

cni_conf = <<EOF
{
  "name": "cbr0",
  "type": "flannel",
  "delegate": {
    "hairpinMode": true,
    "isDefaultGateway": true
  }
}
EOF

kubeconfig_local = <<EOF
---
apiVersion: v1
kind: Config
clusters:
- name: kube_cluster
  cluster:
    server: http://127.0.0.1:62080
users:
- name: kube
contexts:
- name: kube-context
  context:
    cluster: kube_cluster
    user: kube
current-context: kube-context
EOF
