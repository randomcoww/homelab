locals {
  kubernetes = {
    cluster_name                     = "aio-prod-1"
    service_network_dns_netnum       = 10
    service_network_apiserver_netnum = 1
    static_pod_manifest_path         = "/var/lib/kubelet/manifests"
    addon_manifests_path             = "/var/lib/kubernetes/addons"

    metallb_subnet = {
      newbit = 2
      netnum = 1
    }
    metallb_external_dns_netnum = 1
    metallb_pxeboot_netnum      = 2
  }

  container_images = {
    kubelet                 = "ghcr.io/randomcoww/kubernetes:kubelet-v1.22.4"
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