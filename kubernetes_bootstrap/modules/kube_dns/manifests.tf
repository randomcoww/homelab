data "helm_template" "coredns" {
  name       = var.name
  namespace  = var.namespace
  repository = "https://coredns.github.io/helm"
  chart      = "coredns"
  wait       = false
  version    = var.source_release
  values = [
    yamlencode({
      replicaCount = var.replicas
      serviceType  = "ClusterIP"
      serviceAccount = {
        create = false
      }
      service = {
        clusterIP = var.service_cluster_ip
        externalIPs = [
          var.service_ip,
        ]
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
      priorityClassName = "system-cluster-critical"
      servers           = var.servers
      extraContainers = [
        {
          name  = "${var.name}-external-dns"
          image = var.images.external_dns
          args = [
            "--source=service",
            "--source=ingress",
            "--provider=coredns",
            "--log-level=debug",
          ]
        },
        {
          name  = "${var.name}-etcd"
          image = var.images.etcd
          command = [
            "etcd",
          ]
        },
      ]
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
  s = yamldecode(data.helm_template.coredns.manifests["templates/clusterrole.yaml"])
  manifests = merge(data.helm_template.coredns.manifests, {
    "templates/clusterrole.yaml" = yamlencode(merge(local.s, {
      rules = concat(local.s.rules, [
        {
          apiGroups = [""]
          resources = ["services", "pods", "nodes", "endpoints"]
          verbs     = ["get", "watch", "list"]
        },
        {
          apiGroups = ["extensions", "networking.k8s.io"]
          resources = ["ingresses"]
          verbs     = ["get", "watch", "list"]
        },
        {
          apiGroups = ["networking.istio.io"]
          resources = ["gateways"]
          verbs     = ["get", "watch", "list"]
        },
      ])
    }))
  })
}