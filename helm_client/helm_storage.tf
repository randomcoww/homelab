# minio #

resource "helm_release" "minio" {
  name             = split(".", local.kubernetes_service_endpoints.minio)[0]
  namespace        = split(".", local.kubernetes_service_endpoints.minio)[1]
  repository       = "https://charts.min.io/"
  chart            = "minio"
  create_namespace = true
  wait             = false
  version          = "5.0.14"
  values = [
    yamlencode({
      clusterDomain = local.domains.kubernetes
      mode          = "distributed"
      rootUser      = data.terraform_remote_state.sr.outputs.minio.access_key_id
      rootPassword  = data.terraform_remote_state.sr.outputs.minio.secret_access_key
      persistence = {
        storageClass = "local-path"
      }
      drivesPerNode = 2
      replicas      = 1
      resources = {
        requests = {
          memory = "8Gi"
        }
      }
      service = {
        type = "LoadBalancer"
        port = local.service_ports.minio
        externalIPs = [
          local.services.minio.ip,
        ]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.kubernetes_ingress_endpoints.minio
        }
      }
      # ingress = {
      #   enabled          = true
      #   ingressClassName = local.ingress_classes.ingress_nginx
      #   annotations      = local.nginx_ingress_annotations
      #   tls = [
      #     local.tls_wildcard,
      #   ]
      #   hosts = [
      #     local.kubernetes_ingress_endpoints.minio,
      #   ]
      # }
      environment = {
        MINIO_API_REQUESTS_DEADLINE = "2m"
        # MINIO_STORAGE_CLASS_STANDARD = "EC:2"
        # MINIO_STORAGE_CLASS_RRS      = "EC:2"
      }
      buckets = [
        for bucket in local.minio_buckets :
        merge(bucket, {
          purge      = false
          versioning = false
        })
      ]
      users          = []
      policies       = []
      customCommands = []
      svcaccts       = []
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "minio"
                    operator = "Exists"
                  },
                ]
              },
            ]
          }
        }
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      "minio",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
    }),
  ]
}

# mayastor #
/*
resource "helm_release" "mayastor" {
  name             = "mayastor"
  namespace        = "mayastor"
  repository       = "https://openebs.github.io/mayastor-extensions/"
  chart            = "mayastor"
  create_namespace = true
  wait             = false
  version          = "2.4.0"
  values = [
    yamlencode({
      base = {
        metrics = {
          enabled = false
        }
        jaeger = {
          enabled = false
        }
      }
      etcd = {
        clusterDomain = local.domains.kubernetes
        persistence = {
          storageClass = "local-path"
        }
      }
      eventing = {
        enabled = false
      }
      loki-stack = {
        enabled = false
      }
      obs = {
        callhome = {
          enabled = false
        }
      }
    }),
  ]
}
*/