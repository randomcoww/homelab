module "apiserver_lb_service" {
  source    = "../modules/service"
  name      = local.endpoints.apiserver_lb.name
  namespace = local.endpoints.apiserver_lb.namespace
  app       = local.endpoints.apiserver_lb.name
  release   = "0.1.0"
  annotations = {
    "lbipam.cilium.io/ips" = local.endpoints.apiserver_lb.service_ip
  }
  selector = {
    k8s-app = local.endpoints.apiserver_lb.name
  }
  spec = {
    type                  = "LoadBalancer"
    externalTrafficPolicy = "Local"
    ports = [
      {
        name       = "https"
        port       = local.host_ports.apiserver
        protocol   = "TCP"
        targetPort = local.host_ports.apiserver
      },
    ]
  }
}

resource "helm_release" "apiserver-lb-service" {
  chart            = "../helm-wrapper"
  name             = local.endpoints.apiserver_lb.name
  namespace        = local.endpoints.apiserver_lb.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      manifests = concat([
        for _, m in [
          {
            apiVersion = "cilium.io/v2"
            kind       = "CiliumLoadBalancerIPPool"
            metadata = {
              name = "${local.endpoints.apiserver_lb.namespace}-${local.endpoints.apiserver_lb.name}"
            }
            spec = {
              blocks = [
                {
                  cidr = "${local.endpoints.apiserver_lb.service_ip}/32"
                },
              ]
              serviceSelector = {
                matchLabels = {
                  "io.kubernetes.service.namespace" = local.endpoints.apiserver_lb.namespace
                  "io.kubernetes.service.name"      = local.endpoints.apiserver_lb.name
                }
              }
            }
          },
        ] :
        yamlencode(m)
        ], [
        module.apiserver_lb_service.manifest,
      ])
    }),
  ]
}