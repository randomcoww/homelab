# Load balancer

module "kube-vip" {
  source    = "./modules/kube_vip"
  name      = "kube-vip"
  namespace = "kube-system"
  images = {
    kube_vip = local.container_images_digest.kube_vip
  }
  ports = {
    apiserver        = local.host_ports.apiserver,
    kube_vip_metrics = local.host_ports.kube_vip_metrics,
    kube_vip_health  = local.host_ports.kube_vip_health,
  }
  bgp_as     = local.ha.bgp_as
  bgp_peeras = local.ha.bgp_as
  bgp_neighbor_ips = [
    for _, host in local.members.gateway :
    cidrhost(local.networks.service.prefix, host.netnum)
  ]
  apiserver_ip      = local.services.apiserver.ip
  service_interface = "phy-service"
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "node-role.kubernetes.io/control-plane"
                operator = "Exists"
              },
            ]
          },
        ]
      }
    }
  }
}

module "minio" {
  source    = "./modules/minio"
  name      = local.endpoints.minio.name
  namespace = local.endpoints.minio.namespace
  images = {
    nginx = local.container_images_digest.nginx
    minio = {
      repository = regex(local.container_image_regex, local.container_images.minio).depName
      tag        = regex(local.container_image_regex, local.container_images.minio).tag
    }
  }
  ports = {
    minio   = local.service_ports.minio
    metrics = local.service_ports.metrics
  }
  minio_credentials  = data.terraform_remote_state.sr.outputs.minio
  cluster_domain     = local.domains.kubernetes
  ca                 = data.terraform_remote_state.sr.outputs.trust.ca
  service_hostname   = local.endpoints.minio.service
  service_ip         = local.services.minio.ip
  cluster_service_ip = local.services.cluster_minio.ip
}

module "registry" {
  source    = "./modules/registry"
  name      = local.endpoints.registry.name
  namespace = local.endpoints.registry.namespace
  replicas  = 2
  images = {
    registry = local.container_images_digest.registry
  }
  ports = {
    registry = local.service_ports.registry
    metrics  = local.service_ports.metrics
  }
  ca                      = data.terraform_remote_state.sr.outputs.trust.ca
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"

  minio_endpoint      = "${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_access_secret = local.minio_users.registry.secret
  service_hostname    = local.endpoints.registry.service
  service_ip          = local.services.registry.ip
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

# cert-manager

module "cert-manager-issuer-acme-prod-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuers.acme_prod
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.key"        = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.private_key_pem)
    cloudflare-token = data.terraform_remote_state.sr.outputs.cloudflare_dns_api_token
  })
}

module "cert-manager-issuer-ca-internal-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuers.ca_internal
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.crt" = chomp(data.terraform_remote_state.sr.outputs.trust.ca.cert_pem)
    "tls.key" = chomp(data.terraform_remote_state.sr.outputs.trust.ca.private_key_pem)
  })
}

# Generic device plugin

module "device-plugin" {
  source    = "./modules/device_plugin"
  name      = "device-plugin"
  namespace = "kube-system"
  images = {
    device_plugin = local.container_images_digest.device_plugin
  }
  ports = {
    device_plugin_metrics = local.service_ports.metrics
  }
  args = [
    "--device",
    yamlencode({
      name = "rfkill"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/rfkill"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "kvm"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/kvm"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "fuse"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/fuse"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "ntsync"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/ntsync"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "uinput"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/uinput"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "input"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/input"
              type = "Mount"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "tty"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/tty0"
            },
            {
              path = "/dev/tty1"
            },
          ]
        },
      ]
    }),
  ]
  kubelet_root_path = local.kubernetes.kubelet_root_path
}

# DHCP

module "kea" {
  source    = "./modules/kea"
  name      = local.endpoints.kea.name
  namespace = local.endpoints.kea.namespace
  images = {
    kea  = local.container_images_digest.kea
    ipxe = local.container_images_digest.ipxe
  }
  service_ips = [
    local.services.cluster_kea_primary.ip,
    local.services.cluster_kea_secondary.ip,
  ]
  ports = {
    kea_peer    = local.host_ports.kea_peer
    kea_metrics = local.host_ports.kea_metrics
    ipxe        = local.host_ports.ipxe
    ipxe_tftp   = local.host_ports.ipxe_tftp
  }
  ipxe_boot_file_name  = "ipxe.efi"
  ipxe_script_base_url = "https://${local.services.minio.ip}:${local.service_ports.minio}/boot/ipxe-"
  networks = [
    {
      prefix = local.networks.lan.prefix
      routers = [
        local.services.gateway.ip,
      ]
      domain_name_servers = [
        local.services.k8s_gateway.ip,
      ]
      domain_search = [
        local.domains.kubernetes,
        local.domains.public,
      ]
      classless_static_route = [
        # allow local access to these from clients that set default route over VPN
        for _, prefix in distinct([
          local.networks[local.services.apiserver.network.name].prefix,
          local.networks.service.prefix,
          local.networks.kubernetes_service.prefix,
        ]) :
        "${prefix} - ${local.services.gateway.ip}"
      ]
      mtu = lookup(local.networks.lan, "mtu", 1500)
    },
    {
      prefix = local.networks.service.prefix
      mtu    = lookup(local.networks.service, "mtu", 1500)
    },
  ]
  timezone = local.timezone
}

# prometheus

module "prometheus" {
  source    = "./modules/prometheus"
  name      = local.endpoints.prometheus.name
  namespace = local.endpoints.prometheus.namespace
  scrape_configs = yamlencode([
    {
      job_name     = "minio"
      metrics_path = "/minio/metrics/v3/cluster"
      scheme       = "https"
      static_configs = [
        {
          targets = [
            "${local.services.cluster_minio.ip}:${local.service_ports.minio}",
          ]
        },
      ]
    },
    {
      job_name = "cri-o"
      scheme   = "https"
      tls_config = {
        ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
      }
      kubernetes_sd_configs = [
        {
          role = "node"
        },
      ]
      relabel_configs = [
        {
          source_labels = ["__address__"]
          regex         = "([^:]+):\\d+$"
          target_label  = "__address__"
          replacement   = "$1:${local.host_ports.crio_metrics}"
        },
      ]
    },
  ])
  server_files = {
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
          name = "kube-api-server"
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
                absent(up{job="kubernetes-api-servers"})
              or
                changes(up{job="kubernetes-api-servers"}[1m]) > 1
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
                absent(up{app_kubernetes_io_instance="${local.endpoints.kube_dns.name}",namespace="${local.endpoints.kube_dns.namespace}"})
              or
                changes(up{app_kubernetes_io_instance="${local.endpoints.kube_dns.name}",namespace="${local.endpoints.kube_dns.namespace}"}[1m]) > 1
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
  ingress_hostname = local.endpoints.prometheus.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

# github-actions

module "gha-runner" {
  source           = "./modules/gha_runner"
  name             = "gha"
  namespace        = "arc-systems"
  runner_namespace = "arc-runners"
  images = {
    gha_runner = local.container_images_digest.gha_runner
  }
  github_credentials  = var.github
  internal_ca         = data.terraform_remote_state.sr.outputs.trust.ca
  registry_endpoint   = "${local.endpoints.registry.service}:${local.service_ports.registry}"
  minio_endpoint      = "${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_access_secret = local.minio_users.arc.secret
}