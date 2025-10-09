module "minio-metrics-proxy" {
  source  = "../modules/configmap"
  name    = "${local.endpoints.minio.name}-proxy"
  app     = local.endpoints.minio.name
  release = "0.1.0"
  data = {
    "default.conf" = <<-EOF
    proxy_request_buffering off;
    proxy_buffering off;
    proxy_cache off;

    server {
      listen ${local.service_ports.metrics};
      location /minio/metrics/v3 {
        proxy_pass https://127.0.0.1:${local.service_ports.minio};
      }
    }
    EOF
  }
}

resource "helm_release" "minio-resources" {
  name             = "${local.endpoints.minio.name}-resources"
  chart            = "../helm-wrapper"
  namespace        = local.endpoints.minio.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = [
        yamlencode({
          apiVersion = "cert-manager.io/v1"
          kind       = "Certificate"
          metadata = {
            name      = "${local.endpoints.minio.name}-tls"
            namespace = local.endpoints.minio.namespace
          }
          spec = {
            secretName = "${local.endpoints.minio.name}-tls"
            isCA       = false
            privateKey = {
              algorithm = "RSA" # iPXE compatibility
              size      = 4096
            }
            commonName = local.endpoints.minio.name
            usages = [
              "key encipherment",
              "digital signature",
              "server auth",
              "client auth",
            ]
            ipAddresses = [
              "127.0.0.1",
              local.services.minio.ip,
              local.services.cluster_minio.ip,
            ]
            dnsNames = concat([
              "localhost",
              local.endpoints.minio.name,
              local.endpoints.minio.service,
              ], [
              for i, _ in range(local.minio_replicas) :
              "${local.endpoints.minio.name}-${i}.${local.endpoints.minio.name}-svc.${local.endpoints.minio.namespace}.svc"
            ])
            issuerRef = {
              name = local.kubernetes.cert_issuers.ca_internal
              kind = "ClusterIssuer"
            }
          }
        }),
        module.minio-metrics-proxy.manifest,
      ]
    }),
  ]
}

resource "helm_release" "minio" {
  name             = local.endpoints.minio.name
  namespace        = local.endpoints.minio.namespace
  repository       = "https://charts.min.io/"
  chart            = "minio"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  version          = "5.4.0"
  max_history      = 2
  values = [
    yamlencode({
      image = {
        repository = regex(local.container_image_regex, local.container_images.minio).depName
        tag        = regex(local.container_image_regex, local.container_images.minio).tag
      }
      clusterDomain     = local.domains.kubernetes
      mode              = "distributed"
      rootUser          = data.terraform_remote_state.sr.outputs.minio.access_key_id
      rootPassword      = data.terraform_remote_state.sr.outputs.minio.secret_access_key
      priorityClassName = "system-cluster-critical"
      persistence = {
        storageClass = "local-path"
      }
      drivesPerNode = 1
      replicas      = local.minio_replicas
      resources = {
        requests = {
          memory = "12Gi"
        }
      }
      service = {
        type              = "LoadBalancer"
        port              = local.service_ports.minio
        clusterIP         = local.services.cluster_minio.ip
        loadBalancerIP    = local.services.minio.ip
        loadBalancerClass = "kube-vip.io/kube-vip-class"
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = tostring(local.service_ports.metrics)
          "prometheus.io/path"   = "/minio/metrics/v3"
        }
      }
      certsPath = "/opt/minio/certs"
      tls = {
        enabled    = true
        publicCrt  = "tls.crt"
        privateKey = "tls.key"
        certSecret = "${local.endpoints.minio.name}-tls"
      }
      trustedCertsSecret = "${local.endpoints.minio.name}-tls"
      ingress = {
        enabled = false
      }
      environment = {
        MINIO_API_REQUESTS_DEADLINE  = "2m"
        MINIO_STORAGE_CLASS_STANDARD = "EC:2"
        MINIO_STORAGE_CLASS_RRS      = "EC:2"
        MINIO_PROMETHEUS_AUTH_TYPE   = "public"
      }
      buckets        = []
      users          = []
      policies       = []
      customCommands = []
      svcaccts       = []
      extraContainers = [
        # bypass TLS for metrics endpoints
        {
          name  = "${local.endpoints.minio.name}-metrics-proxy"
          image = local.container_images.nginx
          ports = [
            {
              containerPort = local.service_ports.metrics
            },
          ]
          volumeMounts = [
            {
              name      = "metrics-proxy-config"
              mountPath = "/etc/nginx/conf.d/default.conf"
              subPath   = "default.conf"
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