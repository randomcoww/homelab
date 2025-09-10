data "helm_template" "coredns" {
  name       = var.name
  namespace  = var.namespace
  repository = var.helm_template.repository
  chart      = var.helm_template.chart
  version    = var.helm_template.version
  values = [
    yamlencode({
      replicaCount = var.replicas
      serviceType  = "LoadBalancer"
      serviceAccount = {
        create = false
      }
      prometheus = {
        service = {
          enabled = true
        }
      }
      service = {
        clusterIP         = var.service_cluster_ip
        loadBalancerIP    = var.service_ip
        loadBalancerClass = var.loadbalancer_class_name
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
  source    = "../../../modules/metadata"
  name      = var.name
  namespace = var.namespace
  release   = var.helm_template.version
  manifests = local.manifests
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