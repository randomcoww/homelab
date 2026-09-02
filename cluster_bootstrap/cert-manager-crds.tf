data "http" "cert-manager-crds-yaml" {
  url = join("", [
    "https://github.com/cert-manager/cert-manager/releases/download/v",
    trim(
      "1.21.1", # renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
      "v",
    ),
    "/cert-manager.crds.yaml",
  ])
  request_headers = {
    Accept = "application/yaml"
  }
}

resource "helm_release" "cert-manager-crds" {
  chart            = "../helm-wrapper"
  name             = "${local.services.cert-manager.name}-crds"
  namespace        = local.services.cert-manager.namespace
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