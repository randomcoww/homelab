data "http" "metallb-namespace" {
  url = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml"
}

data "http" "metallb" {
  url = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml"
}

data "http" "nginx-ingress-controller" {
  url = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/baremetal/deploy.yaml"
}