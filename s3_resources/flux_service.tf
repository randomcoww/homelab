locals {
  flux_service = merge({

    cloudflare-tunnel = {
      "release.yaml" = join("---\n", [
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
                      service  = "https://${local.endpoints.traefik.service}"
                    } if lookup(e, "tunnel", false)
                  ]
                }
                resources = {
                  requests = {
                    memory = "128Mi"
                  }
                  limits = {
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
        namespace  = "amd"
        resources = [
          "release.yaml",
        ]
      })
    }

    }, {
    for _, m in [
      module.lldap,
      module.authelia-valkey,
      module.authelia,
      module.llama-cpp,
      # module.sunshine-desktop,
      module.searxng,
      module.open-webui,
      module.hostapd,
      module.qrcode-hostapd,
      module.stump,
      module.gha-runner,
      module.navidrome,
      module.mcp-proxy,
    ] :
    m.name => m.kustomize
  })
}