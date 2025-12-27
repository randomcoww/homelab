resource "tls_private_key" "minio" {
  algorithm   = data.terraform_remote_state.sr.outputs.trust.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "minio" {
  private_key_pem = tls_private_key.minio.private_key_pem

  subject {
    common_name = local.endpoints.minio.name
  }
  ip_addresses = [
    "127.0.0.1",
    local.services.minio.ip,
    local.services.cluster_minio.ip,
  ]
  dns_names = concat([
    "localhost",
    local.endpoints.minio.name,
    local.endpoints.minio.service,
    ], [
    for i, _ in range(local.minio_replicas) :
    "${local.endpoints.minio.name}-${i}.${local.endpoints.minio.name}-svc.${local.endpoints.minio.namespace}.svc"
  ])
}

resource "tls_locally_signed_cert" "minio" {
  cert_request_pem   = tls_cert_request.minio.cert_request_pem
  ca_private_key_pem = data.terraform_remote_state.sr.outputs.trust.ca.private_key_pem
  ca_cert_pem        = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
    "server_auth",
  ]
}

module "minio-tls" {
  source  = "../modules/secret"
  name    = "${local.endpoints.minio.name}-tls"
  app     = local.endpoints.minio.name
  release = "0.1.0"
  data = {
    "tls.crt" = tls_locally_signed_cert.minio.cert_pem
    "tls.key" = tls_private_key.minio.private_key_pem
    "ca.crt"  = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  }
}

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
  timeout          = local.kubernetes.helm_release_timeout
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
  name             = local.endpoints.minio.name
  namespace        = local.endpoints.minio.namespace
  repository       = "https://charts.min.io/"
  chart            = "minio"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  version          = "5.4.0"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      image = {
        repository = regex(local.container_image_regex, local.container_images.minio).depName
        tag        = regex(local.container_image_regex, local.container_images.minio).tag
      }
      podAnnotations = {
        "checksum/tls"           = sha256(module.minio-tls.manifest)
        "checksum/metrics-proxy" = sha256(module.minio-metrics-proxy.manifest)
      }
      clusterDomain     = local.domains.kubernetes
      mode              = "distributed"
      rootUser          = data.terraform_remote_state.sr.outputs.minio.access_key_id
      rootPassword      = data.terraform_remote_state.sr.outputs.minio.secret_access_key
      priorityClassName = "system-node-critical"
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
          image = "${regex(local.container_image_regex, local.container_images.nginx).depName}:${regex(local.container_image_regex, local.container_images.nginx).currentValue}"
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