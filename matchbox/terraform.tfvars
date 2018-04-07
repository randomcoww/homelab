matchbox_http_endpoint = "http://192.168.126.242:58080"
matchbox_rpc_endpoint = "192.168.126.242:58081"

hyperkube_image = "gcr.io/google_containers/hyperkube:v1.10.0"
gateway_ip      = "192.168.126.240"
dns_ip          = "192.168.126.244"
default_user    = "core"
ssh_authorized_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCz0pddhkPMJy1DrfdtzEoWsBYeoO609VK8TF1lEir/QHn4vAjvnxBkWD03MMGu8tR6fxqVstmIMEcBzIJ7wak9siVOT/HpCthoGUyIG38qyqdqt0vI5yiJmClGVuDbVILr78PO/C6WgTHfxNkL8FYA6v19u2aaeooc2019aG9SgALuxdYWYNuAoN7QNWL9JBftw8BgeVip4QyLNSkdoh79Th/eiejFIjYxnyDCQiOJZV+w1aevlf7P112k6EZGPfKl0FZ8mFU/vH+GsTqidb6fGuvgdrogk80O4kwzQA3XGjELhzN2OJhe68L5prpEUaNZN9oxkSeg06dFVyrj7sdv"

cluster_dns_ip = "10.3.0.10"
cluster_domain = "cluster.local"

container_linux_version = "1688.3.0"

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
