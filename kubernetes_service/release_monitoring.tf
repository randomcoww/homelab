# Metrics server

resource "helm_release" "metrics-server" {
  name          = "metrics-server"
  namespace     = "kube-system"
  repository    = "https://kubernetes-sigs.github.io/metrics-server"
  chart         = "metrics-server"
  wait          = false
  wait_for_jobs = false
  version       = "3.13.0"
  max_history   = 2
  timeout       = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      replicas = 2
      defaultArgs = [
        "--cert-dir=/tmp",
        "--metric-resolution=15s",
        "--kubelet-preferred-address-types=InternalIP",
        "--kubelet-use-node-status-port",
        "--v=2",
      ]
      dnsConfig = {
        options = [
          {
            name  = "ndots"
            value = "2"
          },
        ]
      }
    }),
  ]
}

# Prometheus

resource "helm_release" "prometheus" {
  name             = local.endpoints.prometheus.name
  namespace        = local.endpoints.prometheus.namespace
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  wait             = false
  wait_for_jobs    = false
  version          = "27.40.0"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      configmapReload = {
        prometheus = {
          enabled = false
        }
      }
      server = {
        strategy = {
          type = "RollingUpdate"
        }
        persistentVolume = {
          enabled = false
        }
        replicaCount = 2
        global = {
          scrape_interval     = "10s"
          scrape_timeout      = "4s"
          evaluation_interval = "10s"
        }
        ingress = {
          enabled          = true
          ingressClassName = local.kubernetes.ingress_classes.ingress_nginx
          annotations      = local.nginx_ingress_annotations
          hosts = [
            local.endpoints.prometheus.ingress,
          ]
          tls = [
            local.ingress_tls_common,
          ]
        }
        extraVolumeMounts = [
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            subPath   = "ca.crt"
            readOnly  = true
          },
        ]
        extraVolumes = [
          {
            name = "ca-trust-bundle"
            configMap = {
              name = local.kubernetes.ca_bundle_configmap
            }
          },
        ]
      }
      extraScrapeConfigs = yamlencode([
        {
          job_name     = "minio-cluster"
          metrics_path = "/minio/metrics/v3/cluster"
          scheme       = "https"
          tls_config = {
            insecure_skip_verify = false
          }
          static_configs = [
            {
              targets = [
                "${local.services.cluster_minio.ip}:${local.service_ports.minio}",
              ]
            },
          ]
        },
      ])
      serverFiles = {
        "alerting_rules.yml" = {
          groups = [
            {
              # https://monitoring.mixins.dev/etcd/
              name = "etcd"
              rules = [
                {
                  alert = "MembersDown"
                  annotations = {
                    summary     = "etcd cluster members are down."
                    description = <<-EOF
                    etcd cluster "{{ $labels.app }}": members are down ({{ $value }}).
                    EOF
                  }
                  expr = <<-EOF
                  (
                    (
                      max by (app) (
                        sum by (app) (up{app="${local.endpoints.etcd.name}",namespace="${local.endpoints.etcd.namespace}"} == bool 0)
                      or
                        count by (app,endpoint) (
                          sum by (app,endpoint,To) (rate(etcd_network_peer_sent_failures_total{app="${local.endpoints.etcd.name}",namespace="${local.endpoints.etcd.namespace}"}[1m])) > 0.01
                        )
                      ) > 0
                    )
                  or
                    count(etcd_server_is_leader{app="${local.endpoints.etcd.name}",namespace="${local.endpoints.etcd.namespace}"} == 1) by (app) > 1
                  or
                    count(etcd_server_has_leader{app="${local.endpoints.etcd.name}",namespace="${local.endpoints.etcd.namespace}"} == 1) by (app) < ${length(local.members.etcd)}
                  )
                  EOF
                  labels = {
                    severity = "critical"
                  }
                },
              ]
            },
            {
              # https://min.io/docs/minio/linux/operations/monitoring/collect-minio-metrics-using-prometheus.html
              name = "minio"
              rules = [
                {
                  alert = "NodesDown"
                  annotations = {
                    summary     = "Node down in MinIO deployment"
                    description = <<-EOF
                    Node(s) in cluster {{ $labels.instance }} offline for more than 1 minute
                    EOF
                  }
                  expr = <<-EOF
                  (
                    absent(up{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"})
                  or
                    avg_over_time(minio_cluster_nodes_offline_total{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}[1m]) > 0
                  )
                  EOF
                  labels = {
                    severity = "critical"
                  }
                },
                {
                  alert = "DisksOffline"
                  annotations = {
                    summary     = "Disks down in MinIO deployment"
                    description = <<-EOF
                    Disks(s) in cluster {{ $labels.instance }} offline for more than 1 minutes
                    EOF
                  }
                  expr = <<-EOF
                  avg_over_time(minio_cluster_drive_offline_total{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}[1m]) > 0
                  EOF
                  labels = {
                    severity = "critical"
                  }
                },
              ]
            },
            {
              name = "kube-apiserver"
              rules = [
                {
                  alert = "NodesDown"
                  annotations = {
                    summary     = "Kube API server nodes down"
                    description = <<-EOF
                    Kube API server nodes {{ $labels.app }} down or flapping
                    EOF
                  }
                  expr = <<-EOF
                  (
                    absent(up{job="kubernetes-apiservers"})
                  or
                    changes(up{job="kubernetes-apiservers"}[1m]) > 1
                  )
                  EOF
                  for  = "1m"
                  labels = {
                    severity = "critical"
                  }
                },
              ]
            },
            {
              # Ref: https://github.com/Azure/AKS/blob/master/examples/kube-prometheus/coredns-prometheusRule.yaml
              name = "kube-dns"
              rules = [
                {
                  alert = "NodesDown"
                  annotations = {
                    summary     = "Kube DNS nodes down"
                    description = <<-EOF
                    CoreDNS nodes {{ $labels.app }} down or flapping
                    EOF
                  }
                  expr = <<-EOF
                  (
                    absent(up{app="${local.endpoints.kube_dns.name}",namespace="${local.endpoints.kube_dns.namespace}"})
                  or
                    changes(up{app="${local.endpoints.kube_dns.name}",namespace="${local.endpoints.kube_dns.namespace}"}[1m]) > 1
                  )
                  EOF
                  for  = "1m"
                  labels = {
                    severity = "critical"
                  }
                },
              ]
            },
            {
              name = "kea"
              rules = [
                {
                  alert = "NodesDown"
                  annotations = {
                    summary     = "Kea nodes down"
                    description = <<-EOF
                    Kea nodes {{ $labels.app }} down or flapping
                    EOF
                  }
                  expr = <<-EOF
                  (
                    absent(up{app="${local.endpoints.kea.name}",namespace="${local.endpoints.kea.namespace}"})
                  or
                    changes(up{app="${local.endpoints.kea.name}",namespace="${local.endpoints.kea.namespace}"}[1m]) > 1
                  )
                  EOF
                  for  = "1m"
                  labels = {
                    severity = "critical"
                  }
                },
              ]
            },
          ]
        }
      }
      alertmanager = {
        enabled = false
      }
      kube-state-metrics = {
        enabled = false
      }
      prometheus-node-exporter = {
        enabled = false
      }
      prometheus-pushgateway = {
        enabled = false
      }
    }),
  ]
}

# Kured

resource "helm_release" "kured" {
  name             = "kured"
  namespace        = "monitoring"
  create_namespace = true
  repository       = "https://kubereboot.github.io/charts"
  chart            = "kured"
  wait             = false
  wait_for_jobs    = false
  version          = "5.10.0"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      configuration = {
        prometheusUrl = "https://${local.endpoints.prometheus.ingress}"
        period        = "2m"
        metricsPort   = local.service_ports.metrics
        forceReboot   = true
        drainTimeout  = "6m"
        blockingPodSelector = [
          "app=arc-runner",
        ]
        timeZone = local.timezone
        # trigger reboot if either /var/run/reboot-required is set, or node failed network boot
        useRebootSentinelHostPath = false
        rebootSentinelCommand     = "sh -c \"if ([ -f /var/run/reboot-required ] || [ -z $(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url=) ]); then exit 0; else exit 1; fi\""
      }
      podAnnotations = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = tostring(local.service_ports.metrics)
      }
      priorityClassName = "system-node-critical"
      service = {
        create = false
      }
    })
  ]
}