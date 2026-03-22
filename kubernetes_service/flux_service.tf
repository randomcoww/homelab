
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

      ] :
      yamlencode(m)
      ],
      module.lldap.flux_manifests,
      module.authelia.flux_manifests,
    ) }),
  ]
}