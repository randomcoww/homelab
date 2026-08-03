resource "minio_s3_bucket" "prometheus" {
  bucket         = "prometheus"
  acl            = "private"
  force_destroy  = true
  object_locking = false
}

resource "minio_iam_user" "prometheus" {
  name          = "prometheus"
  force_destroy = true
}

resource "minio_iam_policy" "prometheus" {
  name = "prometheus"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = [
          minio_s3_bucket.prometheus.arn,
          "${minio_s3_bucket.prometheus.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "prometheus" {
  user_name   = minio_iam_user.prometheus.id
  policy_name = minio_iam_policy.prometheus.id
}

# prometheus (CRDs created in cluster_bootstrap)
module "prometheus" {
  source    = "./modules/prometheus"
  name      = local.endpoints.prometheus.name
  namespace = local.endpoints.prometheus.namespace
  images = {
    thanos = {
      registry   = "quay.io/thanos"
      repository = "thanos"
      tag        = "v0.42.4@sha256:b567818fe608067eb0f1d7c2c4fe361e7ad83c8a256234c97685f1d0bf670cc8" # renovate: datasource=docker depName=quay.io/thanos/thanos
    }
  }
  extra_values = {
    crds = {
      enabled = false # installed earlier in stack
    }
    kubeControllerManager = {
      enabled = false
    }
    kubeScheduler = {
      enabled = false
    }
    kubeProxy = {
      enabled = false # using cilium
    }
    coreDns = {
      enabled = true
      service = {
        enabled    = true
        port       = local.service_ports.coredns_metrics
        targetPort = local.service_ports.coredns_metrics
        selector = {
          "app.kubernetes.io/name" = "coredns"
        }
      }
    }
    kubeEtcd = {
      enabled = true
      service = {
        enabled    = true
        port       = local.host_ports.etcd_metrics
        targetPort = local.host_ports.etcd_metrics
        selector = {
          k8s-app = local.endpoints.etcd.name
        }
      }
    }
    kubelet = {
      enabled = true
    }
  }
  extra_scrape_configs = [
    {
      job_name = "cri-o"
      scheme   = "https"
      tls_config = {
        ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
      }
      bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
      kubernetes_sd_configs = [
        {
          role = "node"
        },
      ]
      relabel_configs = [
        {
          source_labels = ["__meta_kubernetes_node_address_InternalIP"]
          regex         = "(.+)"
          target_label  = "__address__"
          replacement   = "$1:${local.host_ports.crio_metrics}"
        },
        {
          source_labels = ["__meta_kubernetes_node_address_InternalIP"]
          regex         = "(.+)"
          target_label  = "instance"
          replacement   = "$1:${local.host_ports.crio_metrics}"
        },
        {
          source_labels = ["__meta_kubernetes_node_address_Hostname"]
          action        = "replace"
          target_label  = "node"
        },
      ]
    },
  ]
  ingress_hostname = local.endpoints.prometheus.ingress
  gateway_ref = {
    name      = local.endpoints.cilium.name
    namespace = local.endpoints.cilium.namespace
  }
  minio_endpoint = "${local.endpoints.minio.service}:${local.service_ports.minio}"
  minio_bucket   = "prometheus"
  minio_user     = minio_iam_user.prometheus
}

resource "minio_s3_object" "fluxcd-prometheus" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.prometheus.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "prometheus/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}