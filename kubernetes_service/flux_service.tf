
resource "helm_release" "service" {
  name             = "service"
  chart            = "../helm-wrapper"
  namespace        = "flux-runners"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  max_history      = 2
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