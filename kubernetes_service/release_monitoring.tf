# metrics server #

resource "helm_release" "metrics-server" {
  name          = "metrics-server"
  namespace     = "kube-system"
  repository    = "https://kubernetes-sigs.github.io/metrics-server"
  chart         = "metrics-server"
  wait          = false
  wait_for_jobs = false
  version       = "3.13.0"
  max_history   = 2
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

# Blackbox exporter

resource "helm_release" "prometheus-blackbox" {
  name             = local.kubernetes_services.prometheus_blackbox.name
  namespace        = local.kubernetes_services.prometheus_blackbox.namespace
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-blackbox-exporter"
  wait             = false
  wait_for_jobs    = false
  version          = "11.3.1"
  max_history      = 2
  values = [
    yamlencode({
      replicas = 2
      service = {
        port = local.service_ports.prometheus_blackbox
      }
    })
  ]
}

# prometheus #

module "prometheus-ca-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes_services.prometheus.name
  app     = local.kubernetes_services.prometheus.name
  release = "0.1.0"
  data = {
    "ca-cert.pem" = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  }
}

resource "helm_release" "prometheus" {
  name             = local.kubernetes_services.prometheus.name
  namespace        = local.kubernetes_services.prometheus.namespace
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  wait             = false
  wait_for_jobs    = false
  version          = "27.38.0"
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
          ingressClassName = local.kubernetes.ingress_classes.ingress_nginx
          annotations      = local.nginx_ingress_annotations
          hosts = [
            local.ingress_endpoints.monitoring,
          ]
          tls = [
            local.ingress_tls_common,
          ]
        }
        extraVolumeMounts = [
          {
            name      = "config"
            mountPath = "/etc/prometheus/certs/ca-cert.pem"
            subPath   = "ca-cert.pem"
          },
        ]
        extraVolumes = [
          {
            name = "config"
            secret = {
              secretName = module.prometheus-ca-secret.name
            }
          },
        ]
      }
      deploymentUpdate = {
        maxUnavailable = "50%"
      }
      extraManifests = [
        module.prometheus-ca-secret.manifest,
      ]
      extraScrapeConfigs = yamlencode([
        {
          job_name     = "minio-cluster"
          metrics_path = "/minio/metrics/v3/cluster"
          scheme       = "https"
          tls_config = {
            insecure_skip_verify = false
            ca_file              = "/etc/prometheus/certs/ca-cert.pem"
          }
          static_configs = [
            {
              targets = [
                "${local.services.cluster_minio.ip}:${local.service_ports.minio}",
              ]
            },
          ]
        },
        {
          job_name     = "matchbox-blackbox"
          metrics_path = "/probe"
          params = {
            module = [
              "http_2xx",
            ]
          }
          static_configs = [
            {
              targets = [
                "https://${local.services.matchbox.ip}:${local.service_ports.matchbox}",
              ]
            },
          ]
          # chart creates blackbox service name <name>-prometheus-blackbox-exporter
          relabel_configs = [
            {
              source_labels = ["__address__"]
              target_label  = "__param_target"
            },
            {
              source_labels = ["__param_target"]
              target_label  = "instance"
            },
            {
              target_label = "__address__"
              replacement  = "${local.kubernetes_services.prometheus_blackbox.name}-prometheus-blackbox-exporter.${local.kubernetes_services.prometheus_blackbox.namespace}:${local.service_ports.prometheus_blackbox}"
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
                  avg_over_time(minio_cluster_drive_offline_total{app="${local.kubernetes_services.minio.name}",namespace="${local.kubernetes_services.minio.namespace}"}[1m]) > 0
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
                    absent(up{job="kubernetes-apiservers"} == 1)
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
                  alert = "CoreDNSDown"
                  annotations = {
                    summary     = "CoreDNS nodes down"
                    description = <<-EOF
                    CoreDNS nodes {{ $labels.app }} down or flapping
                    EOF
                  }
                  expr = <<-EOF
                  (
                    absent(up{k8s_app="coredns"} == 1)
                  or
                    changes(up{app="kea"}[1m]) > 1
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
                  alert = "KeaNodesDown"
                  annotations = {
                    summary     = "Kea nodes down"
                    description = <<-EOF
                    Kea nodes {{ $labels.app }} down or flapping
                    EOF
                  }
                  expr = <<-EOF
                  (
                    absent(up{app="kea"} == 1)
                  or
                    changes(up{app="kea"}[1m]) > 1
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
              name = "matchbox"
              rules = [
                {
                  alert = "ServiceDown"
                  annotations = {
                    summary     = "Matchbox service down"
                    description = <<-EOF
                    Matchbox service down
                    EOF
                  }
                  expr = <<-EOF
                  (
                    absent(up{job="matchbox-blackbox"} == 1)
                  or
                    changes(up{job="matchbox-blackbox"}[1m]) > 1
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

# kured #

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
  values = [
    yamlencode({
      configuration = {
        # promethues chart creates service name <name>-server
        prometheusUrl = "http://${local.kubernetes_services.prometheus.name}-server.${local.kubernetes_services.prometheus.namespace}:${local.service_ports.prometheus}"
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