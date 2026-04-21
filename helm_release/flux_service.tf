resource "helm_release" "service" {
  name                       = "service"
  chart                      = "../helm-wrapper"
  namespace                  = "flux-runners"
  create_namespace           = true
  wait                       = false
  wait_for_jobs              = false
  max_history                = 1
  disable_crd_hooks          = true
  disable_webhooks           = true
  disable_openapi_validation = true
  skip_crds                  = true
  replace                    = true
  render_subchart_notes      = false
  values = [
    yamlencode({ manifests = concat([
      for _, m in [
        # cloudflare tunnel
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
      ],
      module.lldap.releases,
      module.authelia-valkey.releases,
      module.authelia.releases,
      module.llama-cpp.releases,
      # module.sunshine-desktop.releases,
      module.searxng.releases,
      module.open-webui.releases,
      # module.hostapd.releases,
      module.qrcode-hostapd.releases,
      module.stump.releases,
      module.gha-runner.releases,
      # module.navidrome.releases,
    ) }),
  ]
  depends_on = [
    helm_release.flux2,
  ]
}