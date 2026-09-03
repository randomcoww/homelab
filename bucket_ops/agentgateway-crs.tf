resource "minio_s3_object" "fluxcd-agentgateway-crs" {
  for_each = {
    "manifest.yaml" = join("\n---\n", concat([
      for _, m in [
        {
          apiVersion = "gateway.networking.k8s.io/v1"
          kind       = "Gateway"
          metadata = {
            name      = "${local.agentgateway_name}-proxy"
            namespace = local.agentgateway_namespace
            annotations = {
              "cert-manager.io/cluster-issuer" = local.cert_issuers.acme_prod
            }
          }
          spec = {
            gatewayClassName = "agentgateway"
            listeners = [
              {
                allowedRoutes = {
                  namespaces = {
                    from = "Same"
                  }
                }
                name     = "web"
                port     = 80
                protocol = "HTTP"
              },
              {
                allowedRoutes = {
                  namespaces = {
                    from = "All"
                  }
                }
                hostname = local.endpoints.agentgateway.hostname
                name     = "websecure"
                port     = 443
                protocol = "HTTPS"
                tls = {
                  mode = "Terminate"
                  certificateRefs = [
                    {
                      group = ""
                      name  = "${local.endpoints.agentgateway.hostname}-tls"
                    },
                  ]
                }
              },
            ]
          }
        },
      ] :
      yamlencode(m)
    ]))
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "agentgateway-crs/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}