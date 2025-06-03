# metrics server #

resource "helm_release" "metrics-server" {
  name        = "metrics-server"
  namespace   = "kube-system"
  repository  = "https://kubernetes-sigs.github.io/metrics-server"
  chart       = "metrics-server"
  wait        = false
  version     = "3.12.2"
  max_history = 2
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

# prometheus #

resource "helm_release" "prometheus" {
  name             = local.kubernetes_services.prometheus.name
  namespace        = local.kubernetes_services.prometheus.namespace
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  wait             = false
  version          = "27.19.0"
  max_history      = 2
  values = [
    yamlencode({
      server = {
        persistentVolume = {
          enabled = false
        }
        replicaCount = 2
        global = {
          scrape_interval     = "10s"
          scrape_timeout      = "4s"
          evaluation_interval = "10s"
        }
        service = {
          enabled     = true
          servicePort = local.service_ports.prometheus
        }
        ingress = {
          enabled          = true
          ingressClassName = local.ingress_classes.ingress_nginx
          annotations      = local.nginx_ingress_annotations
          hosts = [
            local.kubernetes_ingress_endpoints.monitoring,
          ]
          tls = [
            local.ingress_tls_common,
          ]
        }
      }
      extraScrapeConfigs = yamlencode([
        {
          job_name     = "minio-job"
          metrics_path = "/minio/v2/metrics/cluster"
          scheme       = "https"
          tls_config = {
            insecure_skip_verify = true
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
                  alert = "etcdMembersDown"
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
                        sum by (app) (up{app="${local.kubernetes_services.etcd.name}",namespace="${local.kubernetes_services.etcd.namespace}"} == bool 0)
                      or
                        count by (app,endpoint) (
                          sum by (app,endpoint,To) (rate(etcd_network_peer_sent_failures_total{app="${local.kubernetes_services.etcd.name}",namespace="${local.kubernetes_services.etcd.namespace}"}[1m])) > 0.01
                        )
                      ) > 0
                    )
                  or
                    count(etcd_server_is_leader{app="${local.kubernetes_services.etcd.name}",namespace="${local.kubernetes_services.etcd.namespace}"} == 1) by (app) > 1
                  or
                    count(etcd_server_has_leader{app="${local.kubernetes_services.etcd.name}",namespace="${local.kubernetes_services.etcd.namespace}"} == 1) by (app) < ${length(local.members.etcd)}
                  )
                  EOF
                  labels = {
                    severity = "critical"
                  }
                },
              ]
            },
            {
              # https://monitoring.mixins.dev/clickhouse/
              name = "alpaca-db"
              rules = [
                {
                  alert = "ClickHouseReplicationQueueBackingUp"
                  annotations = {
                    description = <<-EOF
                    ClickHouse replication tasks are processing slower than expected on {{ $labels.instance }} causing replication queue size to back up at {{ $value }} exceeding the threshold value of 99.
                    EOF
                    summary     = "ClickHouse replica max queue size backing up."
                  }
                  expr            = <<-EOF
                  count(ClickHouseAsyncMetrics_ReplicasMaxQueueSize{app="${local.kubernetes_services.alpaca_db.name}",namespace="${local.kubernetes_services.alpaca_db.namespace}"} > 99) by (app) > 0
                  EOF
                  for             = "5m"
                  keep_firing_for = "5m"
                  labels = {
                    severity = "warning"
                  }
                },
                {
                  alert = "ClickHouseRejectedInserts"
                  annotations = {
                    description = <<-EOF
                    ClickHouse inserts are being rejected on {{ $labels.instance }} as items are being inserted faster than ClickHouse is able to merge them.
                    EOF
                    summary     = "ClickHouse has too many rejected inserts."
                  }
                  expr            = <<-EOF
                  count(ClickHouseProfileEvents_RejectedInserts{app="${local.kubernetes_services.alpaca_db.name}",namespace="${local.kubernetes_services.alpaca_db.namespace}"} > 1) by (app) > 0
                  EOF
                  for             = "5m"
                  keep_firing_for = "5m"
                  labels = {
                    severity = "critical"
                  }
                },
                {
                  alert = "ClickHouseZookeeperSessions"
                  annotations = {
                    description = <<-EOF
                    ClickHouse has more than one connection to a Zookeeper on {{ $labels.instance }} which can lead to bugs due to stale reads in Zookeepers consistency model.
                    EOF
                    summary     = "ClickHouse has too many Zookeeper sessions."
                  }
                  expr            = <<-EOF
                  count(ClickHouseMetrics_ZooKeeperSession{app="${local.kubernetes_services.alpaca_db.name}",namespace="${local.kubernetes_services.alpaca_db.namespace}"} > 1) by (app) > 0
                  EOF
                  for             = "5m"
                  keep_firing_for = "5m"
                  labels = {
                    severity = "critical"
                  }
                },
                {
                  alert = "ClickHouseReplicasInReadOnly"
                  annotations = {
                    description = <<-EOF
                    ClickHouse has replicas in a read only state on {{ $labels.instance }} after losing connection to Zookeeper or at startup.
                    EOF
                    summary     = "ClickHouse has too many replicas in read only state."
                  }
                  expr            = <<-EOF
                  count(ClickHouseMetrics_ReadonlyReplica{app="${local.kubernetes_services.alpaca_db.name}",namespace="${local.kubernetes_services.alpaca_db.namespace}"} > 0) by (app) > 0
                  EOF
                  for             = "5m"
                  keep_firing_for = "5m"
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
                  alert = "NodesOffline"
                  annotations = {
                    summary     = "Node down in MinIO deployment"
                    description = <<-EOF
                    Node(s) in cluster {{ $labels.instance }} offline for more than 1 minute
                    EOF
                  }
                  expr = <<-EOF
                  avg_over_time(minio_cluster_nodes_offline_total{app="${local.kubernetes_services.minio.name}",namespace="${local.kubernetes_services.minio.namespace}"}[1m]) > 0
                  EOF
                  labels = {
                    severity = "warn"
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
                  avg_over_time(minio_cluster_drive_offline_total{app="${local.kubernetes_services.minio.name}",namespace="${local.kubernetes_services.minio.namespace}"}[1m]) > 0
                  EOF
                  labels = {
                    severity = "warn"
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