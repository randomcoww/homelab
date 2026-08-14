locals {
  k8s-gateway_name      = "k8s-gateway"
  k8s-gateway_namespace = "kube-system"
}

resource "minio_s3_object" "fluxcd-k8s-gateway" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = local.k8s-gateway_name
            namespace = local.k8s-gateway_namespace
          }
          spec = {
            interval = "15m"
            url      = "https://k8s-gateway.github.io/k8s_gateway"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = local.k8s-gateway_name
            namespace = local.k8s-gateway_namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "k8s-gateway"
                version = "3.7.2" # renovate: datasource=helm depName=k8s-gateway registryUrl=https://k8s-gateway.github.io/k8s_gateway
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.k8s-gateway_name
                }
                interval = "5m"
              }
            }
            releaseName = local.k8s-gateway_name
            install = {
              createNamespace = true
              remediation = {
                retries = -1
              }
            }
            upgrade = {
              remediation = {
                retries = -1
              }
            }
            test = {
              enable = false
            }
            values = {
              domain = "."
              watchedResources = [
                "Service",
                "HTTPRoute",
              ]
              fallthrough = {
                enabled = true
              }
              resources = {
                requests = {
                  memory = "128Mi"
                }
                limits = {
                  memory = "256Mi"
                }
              }
              service = {
                type = "LoadBalancer"
                labels = {
                  app = local.k8s-gateway_name
                }
                annotations = {
                  "lbipam.cilium.io/ips" = local.networks.service.vips.k8s-gateway
                }
                useTcp = true
              }
              affinity = {
                podAntiAffinity = {
                  requiredDuringSchedulingIgnoredDuringExecution = [
                    {
                      labelSelector = {
                        matchExpressions = [
                          {
                            key      = "app.kubernetes.io/instance"
                            operator = "In"
                            values = [
                              local.k8s-gateway_name,
                            ]
                          },
                        ]
                      }
                      topologyKey = "kubernetes.io/hostname"
                    },
                  ]
                }
              }
              replicaCount = 3
              extraZonePlugins = concat([
                {
                  name = "health"
                },
                {
                  name = "ready"
                },
                {
                  name = "loop"
                },
                {
                  name       = "prometheus"
                  parameters = "0.0.0.0:${local.service_ports.coredns_metrics}"
                },
                {
                  name = "hosts"
                  configBlock = join("\n", concat(compact([
                    for _, host in local.hosts :
                    try("${cidrhost(host.networks.service.prefix, host.netnum)} ${host.key}.${local.domains.kubernetes}", "")
                    ]), [
                    "fallthrough"
                  ]))
                },
                ], [
                for tlshostname, ips in merge({
                  for _, d in local.upstream_dns :
                  d.hostname => d.ip...
                }) :
                {
                  name = "forward"
                  parameters = ". ${join(" ", [
                    for _, ip in ips :
                    "tls://${ip}"
                  ])}"
                  configBlock = <<-EOF
                  tls_servername ${tlshostname}
                  health_check 5s
                  EOF
                }
              ])
            }
          }
        },

        # monitoring
        {
          apiVersion = "monitoring.coreos.com/v1"
          kind       = "ServiceMonitor"
          metadata = {
            name      = "k8s-gateway"
            namespace = "kube-system"
          }
          spec = {
            selector = {
              matchLabels = {
                app = "k8s-gateway"
              }
            }
            endpoints = [
              {
                path       = "/metrics"
                targetPort = local.service_ports.coredns_metrics
              },
            ]
          }
        },

        # static service IP
        {
          apiVersion = "cilium.io/v2"
          kind       = "CiliumLoadBalancerIPPool"
          metadata = {
            name = "${local.k8s-gateway_namespace}-${local.k8s-gateway_name}"
          }
          spec = {
            blocks = [
              {
                cidr = "${local.networks.service.vips.k8s-gateway}/32"
              },
            ]
            serviceSelector = {
              matchLabels = {
                "io.kubernetes.service.namespace" = local.k8s-gateway_namespace
                "io.kubernetes.service.name"      = local.k8s-gateway_name
              }
            }
          }
        },
      ] :
      yamlencode(m)
    ])
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "k8s-gateway/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}