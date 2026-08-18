resource "minio_s3_object" "fluxcd-tailscale-operator" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "tailscale-operator"
            namespace = "tailscale"
          }
          spec = {
            interval = "15m"
            url      = "https://pkgs.tailscale.com/helmcharts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "tailscale-operator"
            namespace = "tailscale"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "tailscale-operator"
                version = "1.102.2" # renovate: datasource=helm depName=tailscale-operator registryUrl=https://pkgs.tailscale.com/helmcharts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "tailscale-operator"
                }
                interval = "5m"
              }
            }
            releaseName = "tailscale-operator"
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
              oauth = {
                clientId     = data.terraform_remote_state.sr.outputs.tailscale_oauth_client.id
                clientSecret = data.terraform_remote_state.sr.outputs.tailscale_oauth_client.key
              }
              operatorConfig = {
                resources = {
                  requests = {
                    memory = "32Mi"
                  }
                  limits = {
                    memory = "64Mi"
                  }
                }
              }
            }
          }
        },

        # NS
        {
          apiVersion = "v1"
          kind       = "Namespace"
          metadata = {
            name = "tailscale"
            annotations = {
              "kustomize.toolkit.fluxcd.io/prune" = "disabled"
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
  object_name  = "tailscale-operator/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}