data "http" "metallb-namespace" {
  url = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml"
}

data "http" "metallb" {
  url = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml"
}