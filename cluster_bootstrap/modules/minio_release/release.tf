resource "helm_release" "wrapper" {
  chart            = "../helm-wrapper"
  name             = "${var.name}-resources"
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = [
        module.minio-tls.manifest,
      ]
    }),
  ]
}

resource "helm_release" "minio" {
  name             = var.name
  namespace        = var.namespace
  repository       = "https://charts.min.io"
  chart            = "minio"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "5.4.0"
  max_history      = 2
  timeout          = var.timeout
  values = [
    yamlencode({
      image = {
        repository = var.images.minio.repository
        tag        = var.images.minio.tag
      }
      podAnnotations = {
        "checksum/tls" = sha256(module.minio-tls.manifest)
      }
      clusterDomain     = var.cluster_domain
      mode              = "distributed"
      rootUser          = var.root_user.id
      rootPassword      = var.root_user.secret
      priorityClassName = "system-node-critical"
      persistence = {
        storageClass = "local-path"
      }
      drivesPerNode = 1
      replicas      = var.replicas
      resources = {
        requests = {
          memory = "4Gi"
        }
        limits = {
          memory = "4Gi"
        }
      }
      service = {
        type              = "LoadBalancer"
        port              = var.ports.minio
        clusterIP         = var.cluster_service_ip
        loadBalancerClass = "kube-vip.io/kube-vip-class"
        annotations = {
          "kube-vip.io/loadbalancerIPs" = var.service_ip
        }
      }
      certsPath = "/opt/minio/certs"
      tls = {
        enabled    = true
        publicCrt  = "tls.crt"
        privateKey = "tls.key"
        certSecret = module.minio-tls.name
      }
      trustedCertsSecret = module.minio-tls.name
      ingress = {
        enabled = false
      }
      environment = {
        MINIO_API_REQUESTS_DEADLINE  = "2m"
        MINIO_STORAGE_CLASS_STANDARD = "EC:2"
        MINIO_STORAGE_CLASS_RRS      = "EC:2"
      }
      buckets        = []
      users          = []
      policies       = []
      customCommands = []
      svcaccts       = []
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
    }),
  ]
}