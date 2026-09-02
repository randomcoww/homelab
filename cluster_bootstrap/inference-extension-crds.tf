data "http" "inference-extension-crds-yaml" {
  url = join("/", [
    "https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download",
    "v1.6.0", # renovate: datasource=github-releases depName=kubernetes-sigs/gateway-api-inference-extension
    "v1-manifests.yaml",
  ])
  request_headers = {
    Accept = "application/yaml"
  }
}

resource "helm_release" "inference-extension-crds" {
  chart            = "../helm-wrapper"
  name             = "inference-extension-crds"
  namespace        = "kube-system"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      manifests = [
        data.http.inference-extension-crds-yaml.response_body,
      ]
    }),
  ]
}