
# minio #

locals {
  minio_replicas = 4
}

resource "tls_private_key" "minio" {
  algorithm   = data.terraform_remote_state.sr.outputs.trust.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "minio" {
  private_key_pem = tls_private_key.minio.private_key_pem

  subject {
    common_name = "${local.kubernetes_services.minio.name}-server"
  }

  dns_names = concat([
    "localhost",
    local.kubernetes_services.minio.name,
    "${local.kubernetes_services.minio.name}.${local.kubernetes_services.minio.namespace}",
    ], [
    for i, _ in range(local.minio_replicas) :
    "${local.kubernetes_services.minio.name}-${i}.${local.kubernetes_services.minio.name}-svc.${local.kubernetes_services.minio.namespace}.svc"
  ])
  ip_addresses = [
    "127.0.0.1",
    local.services.minio.ip,
    local.services.cluster_minio.ip,
  ]
}

resource "tls_locally_signed_cert" "minio" {
  cert_request_pem   = tls_cert_request.minio.cert_request_pem
  ca_private_key_pem = data.terraform_remote_state.sr.outputs.trust.ca.private_key_pem
  ca_cert_pem        = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

module "minio-client-secret" {
  source  = "../modules/secret"
  name    = "${local.kubernetes_services.minio.name}-client"
  app     = local.kubernetes_services.minio.name
  release = "0.1.0"
  data = merge({
    "public.crt"  = tls_locally_signed_cert.minio.cert_pem
    "private.key" = tls_private_key.minio.private_key_pem
  })
}

module "minio-ca-secret" {
  source  = "../modules/secret"
  name    = "${local.kubernetes_services.minio.name}-ca"
  app     = local.kubernetes_services.minio.name
  release = "0.1.0"
  data = merge({
    "ca.crt" = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  })
}

resource "helm_release" "minio-tls" {
  name        = "${local.kubernetes_services.minio.name}-tls"
  chart       = "../helm-wrapper"
  namespace   = local.kubernetes_services.minio.namespace
  wait        = false
  max_history = 2
  values = [
    yamlencode({
      manifests = [
        module.minio-client-secret.manifest,
        module.minio-ca-secret.manifest,
      ]
    }),
  ]
}

resource "helm_release" "minio" {
  name             = local.kubernetes_services.minio.name
  namespace        = local.kubernetes_services.minio.namespace
  repository       = "https://charts.min.io/"
  chart            = "minio"
  create_namespace = true
  wait             = true
  timeout          = 60
  version          = "5.4.0"
  max_history      = 2
  values = [
    yamlencode({
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
          memory = "16Gi"
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
          "prometheus.io/path"   = "/minio/v2/metrics/node"
        }
      }
      certsPath = "/opt/minio/certs"
      tls = {
        enabled    = true
        publicCrt  = "public.crt"
        privateKey = "private.key"
        certSecret = "${local.kubernetes_services.minio.name}-client"
      }
      podAnnotations = {
        "checksum/client-cert" = sha256(module.minio-client-secret.manifest)
        "checksum/ca-cert"     = sha256(module.minio-ca-secret.manifest)
      }
      trustedCertsSecret = "${local.kubernetes_services.minio.name}-ca"
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
          name  = "${local.kubernetes_services.minio.name}-metrics"
          image = local.container_images.nginx
          securityContext = {
            runAsUser = 0
          }
          command = [
            "sh",
            "-c",
            <<-EOT
            set -e

            cat > /etc/nginx/conf.d/default.conf <<EOF
            proxy_request_buffering off;
            proxy_buffering off;

            server {
              listen      ${local.service_ports.metrics};
              server_name localhost;

              location /minio/v2/metrics {
                proxy_pass https://127.0.0.1:${local.service_ports.minio};
              }

              location /minio/metrics/v3 {
                proxy_pass https://127.0.0.1:${local.service_ports.minio};
              }
            }
            EOF

            exec nginx -g 'daemon off;'
            EOT
          ]
          ports = [
            {
              containerPort = local.service_ports.metrics
            },
          ]
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
  depends_on = [
    kubernetes_labels.labels,
  ]
}