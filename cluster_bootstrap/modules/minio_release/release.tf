module "minio-metrics-proxy" {
  source    = "../../../modules/configmap"
  name      = "${var.name}-proxy"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    "nginx-proxy.conf" = <<-EOF
    proxy_request_buffering off;
    proxy_buffering off;
    proxy_cache off;

    server {
      listen ${var.ports.metrics};
      location /minio/metrics/v3 {
        proxy_pass https://127.0.0.1:${var.ports.minio};

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }
    }
    EOF
  }
}

resource "helm_release" "wrapper" {
  chart            = "../helm-wrapper"
  name             = "${var.name}-resources"
  namespace        = var.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = [
        module.minio-tls.manifest,
        module.minio-metrics-proxy.manifest,
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
  wait             = false
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
        "checksum/tls"           = sha256(module.minio-tls.manifest)
        "checksum/metrics-proxy" = sha256(module.minio-metrics-proxy.manifest)
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
          "prometheus.io/scrape"        = "true"
          "prometheus.io/port"          = tostring(var.ports.metrics)
          "prometheus.io/path"          = "/minio/metrics/v3"
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
      extraContainers = [
        # bypass TLS for metrics endpoints
        {
          name  = "${var.name}-metrics-proxy"
          image = var.images.nginx
          ports = [
            {
              containerPort = var.ports.metrics
            },
          ]
          volumeMounts = [
            {
              name      = "metrics-proxy-config"
              mountPath = "/etc/nginx/conf.d/default.conf"
              subPath   = "nginx-proxy.conf"
            },
          ]
        },
      ]
      extraVolumes = [
        {
          name = "metrics-proxy-config"
          configMap = {
            name = module.minio-metrics-proxy.name
          }
        },
      ]
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