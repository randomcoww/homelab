# prometheus (CRDs created in cluster_bootstrap)
module "prometheus" {
  source    = "./modules/prometheus"
  name      = local.endpoints.prometheus.name
  namespace = local.endpoints.prometheus.namespace
  images = {
    thanos = {
      registry   = regex(local.container_image_regex, local.container_images.thanos).repository
      repository = regex(local.container_image_regex, local.container_images.thanos).image
      tag        = regex(local.container_image_regex, local.container_images.thanos).tag
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
          app = local.endpoints.kube_dns.name
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
  minio_user     = minio_iam_user.user["prometheus"]
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
    minio_s3_bucket.bucket["fluxcd"],
  ]
}