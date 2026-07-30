resource "minio_s3_object" "fluxcd-cloudflare-tunnel" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "cloudflare-tunnel"
            namespace = "default"
          }
          spec = {
            interval = "15m"
            url      = "https://cloudflare.github.io/helm-charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "cloudflare-tunnel"
            namespace = "default"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "cloudflare-tunnel"
                version = "0.3.2" # renovate: datasource=helm depName=cloudflare-tunnel registryUrl=https://cloudflare.github.io/helm-charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "cloudflare-tunnel"
                }
                interval = "5m"
              }
            }
            releaseName = "cloudflare-tunnel"
            install = {
              createNamespace = true
              remediation = {
                retries = -1
              }
            }
            upgrade = {
              remediation = {
                retries = -1
              }
            }
            test = {
              enable = false
            }
            values = {
              image = {
                repository = regex(local.container_image_regex, local.container_images.cloudflared).depName
                tag        = regex(local.container_image_regex, local.container_images.cloudflared).tag
              }
              cloudflare = {
                account    = data.terraform_remote_state.sr.outputs.cloudflare_tunnel.account_id
                tunnelName = data.terraform_remote_state.sr.outputs.cloudflare_tunnel.name
                tunnelId   = data.terraform_remote_state.sr.outputs.cloudflare_tunnel.id
                secret     = data.terraform_remote_state.sr.outputs.cloudflare_tunnel.tunnel_secret
                ingress = [
                  for _, e in local.endpoints :
                  {
                    hostname = e.ingress
                    service  = "https://${e.ingress}"
                  } if lookup(e, "tunnel", false)
                ]
              }
              resources = {
                requests = {
                  memory = "128Mi"
                }
              }
            }
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
  object_name  = "cloudflare-tunnel/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}