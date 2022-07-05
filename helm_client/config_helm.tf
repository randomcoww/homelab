locals {
  helm_ingress = {
    mpd_stream  = "s.${local.domains.internal}"
    mpd_control = "mpd.${local.domains.internal}"
  }

  helm_container_images = {
    matchbox  = "quay.io/poseidon/matchbox:latest"
    hostapd   = "ghcr.io/randomcoww/hostapd:latest"
    syncthing = "docker.io/syncthing/syncthing:latest"
    rclone    = "docker.io/rclone/rclone:latest"
    mpd       = "ghcr.io/randomcoww/mpd:0.23.7"
    ympd      = "ghcr.io/randomcoww/ympd:latest"
  }
}