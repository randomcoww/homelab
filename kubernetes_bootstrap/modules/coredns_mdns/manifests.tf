data "helm_template" "coredns" {
  name       = var.name
  namespace  = var.namespace
  repository = "https://coredns.github.io/helm"
  chart      = "coredns"
  wait       = false
  version    = var.source_release
  values = [
    yamlencode({
      image = {
        repository = split(":", var.images.coredns)[0]
        tag        = split(":", var.images.coredns)[1]
      }
      replicaCount = var.replicas
      serviceType  = "ClusterIP"
      serviceAccount = {
        create = false
      }
      service = {
        clusterIP = var.service_cluster_ip
      }
      affinity = {
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      var.name,
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      servers = var.servers
    })
  ]
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.source_release
  app_version = var.source_release
  manifests   = local.manifests
}

locals {
  d = yamldecode(data.helm_template.coredns.manifests["templates/deployment.yaml"])
  manifests = merge(data.helm_template.coredns.manifests, {
    "templates/deployment.yaml" = yamlencode(merge(local.d, {
      spec = merge(local.d.spec, {
        template = merge(local.d.spec.template, {
          spec = merge(local.d.spec.template.spec, {
            hostNetwork = true
          })
        })
      })
    }))
  })
}