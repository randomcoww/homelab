locals {
  helm_ingress = {
    mpd  = "mpd.${local.domains.internal}"
    auth = "auth.${local.domains.internal}"
  }

  helm_container_images = {
    matchbox  = "quay.io/poseidon/matchbox:latest"
    hostapd   = "ghcr.io/randomcoww/hostapd:latest"
    syncthing = "docker.io/syncthing/syncthing:latest"
    rclone    = "docker.io/rclone/rclone:latest"
    mpd       = "ghcr.io/randomcoww/mpd:0.23.8"
    ympd      = "ghcr.io/randomcoww/ympd:latest"
  }
}