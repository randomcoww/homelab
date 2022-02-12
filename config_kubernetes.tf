locals {
  kubernetes = {
    cluster_name             = "aio-prod-4"
    static_pod_manifest_path = "/var/lib/kubelet/manifests"
    addon_manifests_path     = "/var/lib/kubernetes/addons"
  }

  container_images = {
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
    kube_proxy              = "ghcr.io/randomcoww/kubernetes:kube-proxy-v1.22.4"
    kube_addons_manager     = "ghcr.io/randomcoww/kubernetes-addon-manager:master"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:latest"
    etcd                    = "ghcr.io/randomcoww/etcd:v3.5.1"
    kea                     = "ghcr.io/randomcoww/kea:2.0.0"
    tftpd                   = "ghcr.io/randomcoww/tftpd-ipxe:master"
    coredns                 = "docker.io/coredns/coredns:latest"
    flannel                 = "ghcr.io/randomcoww/flannel:v0.15.0"
    flannel-cni-plugin      = "rancher/mirrored-flannelcni-flannel-cni-plugin:v1.0.0"
    minio                   = "minio/minio:latest"
    hostapd                 = "ghcr.io/randomcoww/hostapd:latest"
    kapprover               = "ghcr.io/randomcoww/kapprover:latest"
    external_dns            = "k8s.gcr.io/external-dns/external-dns:v0.10.2"
    matchbox                = "quay.io/poseidon/matchbox:latest"
    syncthing               = "docker.io/syncthing/syncthing:latest"
  }
}