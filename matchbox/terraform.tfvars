matchbox_http_endpoint = "http://haproxy.svc.internal:48080"
matchbox_rpc_endpoint = "haproxy.svc.internal:48081"

hyperkube_image = "gcr.io/google_containers/hyperkube:v1.9.4"
gateway_ip      = "192.168.126.240"
dns_ip          = "192.168.126.244"
default_user    = "core"
ssh_authorized_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCz0pddhkPMJy1DrfdtzEoWsBYeoO609VK8TF1lEir/QHn4vAjvnxBkWD03MMGu8tR6fxqVstmIMEcBzIJ7wak9siVOT/HpCthoGUyIG38qyqdqt0vI5yiJmClGVuDbVILr78PO/C6WgTHfxNkL8FYA6v19u2aaeooc2019aG9SgALuxdYWYNuAoN7QNWL9JBftw8BgeVip4QyLNSkdoh79Th/eiejFIjYxnyDCQiOJZV+w1aevlf7P112k6EZGPfKl0FZ8mFU/vH+GsTqidb6fGuvgdrogk80O4kwzQA3XGjELhzN2OJhe68L5prpEUaNZN9oxkSeg06dFVyrj7sdv"

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


# [Service]
# ExecStartPre=/usr/bin/mkdir -p /var/log/containers
# ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/run/matchbox-pod.uuid
# ExecStart=/usr/bin/rkt run \
#   --insecure-options=image \
#   --uuid-file-save=/var/run/matchbox-pod.uuid \
#   \
#   --volume dns,kind=host,source=/etc/resolv.conf \
#   --volume etc-ssl-certs,kind=host,source=/etc/ssl/certs,readOnly=true \
#   --volume usr-share-certs,kind=host,source=/etc/pki/ca-trust,readOnly=true \
#   --volume matchbox-data,kind=host,source=/data/matchbox \
#   \
#   --mount volume=dns,target=/etc/resolv.conf \
#   --mount volume=etc-ssl-certs,target=/etc/ssl/certs \
#   --mount volume=usr-share-certs,target=/etc/pki/ca-trust \
#   --mount volume=matchbox-data,target=/data/matchbox \
#   \
#   --hosts-entry host \
#   --stage1-from-dir=stage1-fly.aci docker://{{.matchbox_image}} \
#   --exec=/matchbox -- \
#   -address=0.0.0.0:48080 \
#   -rpc-address=0.0.0.0:48081 \
#   -ca-file=/etc/ssl/certs/matchbox-ca.pem \
#   -cert-file=/etc/ssl/certs/matchbox.pem \
#   -key-file=/etc/ssl/certs/matchbox-key.pem \
#   -data-path=/data/matchbox \
#   -assets-path=/data/matchbox/assets \
# ExecStop=-/usr/bin/rkt stop --uuid-file=/var/run/matchbox-pod.uuid
# Restart=always
# RestartSec=10
#
# [Install]
# WantedBy=multi-user.target
