locals {
  helm_ingress = {
    mpd  = "mpd.${local.domains.internal}"
    auth = "auth.${local.domains.internal}"
  }

  helm_container_images = {
    matchbox           = "quay.io/poseidon/matchbox:latest"
    hostapd            = "ghcr.io/randomcoww/hostapd:latest"
    syncthing          = "docker.io/syncthing/syncthing:latest"
    rclone             = "docker.io/rclone/rclone:latest"
    mpd                = "ghcr.io/randomcoww/mpd:0.23.8-2"
    ympd               = "ghcr.io/randomcoww/ympd:latest"
    flannel            = "ghcr.io/randomcoww/flannel:v0.18.1"
    flannel_cni_plugin = "rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.0"
    kapprover          = "ghcr.io/randomcoww/kapprover:latest"
    external_dns       = "k8s.gcr.io/external-dns/external-dns:v0.12.0"
    kube_proxy         = "ghcr.io/randomcoww/kubernetes:kube-proxy-v1.24.1"
  }
}