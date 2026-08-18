resource "helm_release" "cert-manager" {
  name             = local.services.cert-manager.name
  namespace        = local.services.cert-manager.namespace
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "v1.21.1"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      replicaCount = 2
      deploymentAnnotations = {
        "certmanager.k8s.io/disable-validation" = "true"
      }
      crds = {
        enabled = false
      }
      enableCertificateOwnerRef = true
      config = {
        enableGatewayAPI = true
      }
      prometheus = {
        enabled = true
        servicemonitor = {
          enabled = true
        }
      }
      webhook = {
        replicaCount = 2
        resources = {
          requests = {
            memory = "128Mi"
          }
          limits = {
            memory = "256Mi"
          }
        }
      }
      resources = {
        requests = {
          memory = "128Mi"
        }
        limits = {
          memory = "256Mi"
        }
      }
      cainjector = {
        enabled      = true
        replicaCount = 2
        resources = {
          requests = {
            memory = "160Mi"
          }
          limits = {
            memory = "256Mi"
          }
        }
      }
      startupapicheck = {
        enabled = true
      }
      extraArgs = [
        "--dns01-recursive-nameservers-only",
        "--dns01-recursive-nameservers=${join(",", [
          for _, d in local.upstream_dns :
          "${d.ip}:53"
        ])}",
      ]
      podDnsConfig = {
        options = [
          {
            name  = "ndots"
            value = "2"
          },
        ]
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

resource "helm_release" "cert-manager-csi-driver" {
  name             = "${local.services.cert-manager.name}-csi-driver"
  namespace        = local.services.cert-manager.namespace
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager-csi-driver"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "v0.16.0"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      metrics = {
        enabled = true
        podmonitor = {
          enabled = true
        }
      }
      resources = {
        requests = {
          memory = "128Mi"
        }
        limits = {
          memory = "256Mi"
        }
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}