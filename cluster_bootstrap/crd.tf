locals {
  cert_manager_version = "1.21.0" # renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
}

data "http" "cert-manager-crds-yaml" {
  url = "https://github.com/cert-manager/cert-manager/releases/download/v${local.cert_manager_version}/cert-manager.crds.yaml"
  request_headers = {
    Accept = "application/yaml"
  }
}

resource "helm_release" "cert-manager-crds" {
  chart            = "../helm-wrapper"
  name             = "${local.endpoints.cert_manager.name}-crds"
  namespace        = local.endpoints.cert_manager.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      manifests = [
        data.http.cert-manager-crds-yaml.response_body,
      ]
    }),
  ]
}

resource "helm_release" "prometheus-operator-crds" {
  name             = "${local.endpoints.prometheus.name}-crds"
  namespace        = local.endpoints.prometheus.namespace
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-operator-crds"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "30.0.1"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
    }),
  ]
}