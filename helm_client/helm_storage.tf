# minio #

resource "random_password" "minio-access-key-id" {
  length  = 30
  special = false
}

resource "random_password" "minio-secret-access-key" {
  length  = 30
  special = false
}

resource "helm_release" "minio" {
  name             = split(".", local.kubernetes_service_endpoints.minio)[0]
  namespace        = split(".", local.kubernetes_service_endpoints.minio)[1]
  repository       = "https://charts.min.io/"
  chart            = "minio"
  create_namespace = true
  wait             = false
  version          = "5.0.13"
  values = [
    yamlencode({
      clusterDomain = local.domains.kubernetes
      mode          = "distributed"
      rootUser      = random_password.minio-access-key-id.result
      rootPassword  = random_password.minio-secret-access-key.result
      persistence = {
        storageClass = "local-path"
      }
      drivesPerNode = 2
      replicas      = 3
      resources = {
        requests = {
          memory = "8Gi"
        }
      }
      service = {
        type = "LoadBalancer"
        port = local.ports.minio
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
      #     {
      #       secretName = "minio-tls"
      #       hosts = [
      #         local.kubernetes_ingress_endpoints.minio,
      #       ]
      #     },
      #   ]
      #   hosts = [
      #     local.kubernetes_ingress_endpoints.minio,
      #   ]
      # }
      environment = {
        MINIO_API_REQUESTS_DEADLINE  = "2m"
        MINIO_STORAGE_CLASS_STANDARD = "EC:2"
        MINIO_STORAGE_CLASS_RRS      = "EC:2"
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
                    key      = "kubernetes.io/hostname"
                    operator = "In"
                    values = [
                      for _, member in local.members.disks :
                      member.hostname
                    ]
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

output "mc_config" {
  value = {
    version = "10"
    aliases = {
      m = {
        url       = "http://${local.kubernetes_ingress_endpoints.minio}:${local.ports.minio}"
        accessKey = nonsensitive(random_password.minio-access-key-id.result)
        secretKey = nonsensitive(random_password.minio-secret-access-key.result)
        api       = "S3v4"
        path      = "auto"
      }
      s3 = {
        url       = "https://s3.amazonaws.com"
        accessKey = aws_iam_access_key.s3-backup.id
        secretKey = nonsensitive(aws_iam_access_key.s3-backup.secret)
        api       = "S3v4"
        path      = "auto"
      }
    }
  }
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
  version          = "2.3.0"
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