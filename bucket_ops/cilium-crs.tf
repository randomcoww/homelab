# Cilium with CRDs installed in bootstrap

resource "minio_s3_object" "fluxcd-cilium-crs" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "cilium.io/v2"
          kind       = "CiliumLoadBalancerIPPool"
          metadata = {
            name = "service"
          }
          spec = {
            blocks = [
              {
                start = cidrhost(cidrsubnet(local.networks.service.prefix, 2, 1), 1)
                stop  = cidrhost(local.networks.service.prefix, -2)
              },
            ]
          }
        },
        {
          apiVersion = "gateway.networking.k8s.io/v1"
          kind       = "Gateway"
          metadata = {
            name      = local.endpoints.cilium.name
            namespace = local.endpoints.cilium.namespace
            annotations = {
              "cert-manager.io/cluster-issuer" = local.cert_issuers.acme_prod
            }
          }
          spec = {
            gatewayClassName = "cilium"
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
                hostname = "*.${local.domains.public}"
                name     = "websecure"
                port     = 443
                protocol = "HTTPS"
                tls = {
                  mode = "Terminate"
                  certificateRefs = [
                    {
                      group = ""
                      name  = "${local.domains.public}-tls"
                    },
                  ]
                }
              },
            ]
          }
        },
      ] :
      yamlencode(m)
    ])
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "cilium-crs/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}