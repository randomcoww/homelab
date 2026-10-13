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
          kind       = "OCIRepository"
          metadata = {
            name      = local.k8s-gateway_name
            namespace = local.k8s-gateway_namespace
          }
          spec = {
            interval = "15m"
            url      = "oci://codeberg.org/k8s-gateway/charts/k8s-gateway"
            ref = {
              tag = "4.0.1" # renovate: datasource=docker depName=codeberg.org/k8s-gateway/charts/k8s-gateway depType=helm_regex
            }
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
            chartRef = {
              kind      = "OCIRepository"
              name      = local.k8s-gateway_name
              namespace = local.k8s-gateway_namespace
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
              replicaCount = 2
              serviceType  = "LoadBalancer"
              serviceAccount = {
                create = true
              }
              rbac = {
                create = true
              }
              prometheus = {
                service = {
                  enabled = true
                }
                monitor = {
                  enabled = true
                }
              }
              service = {
                annotations = {
                  "lbipam.cilium.io/ips" = local.networks.service.vips.k8s-gateway
                }
              }
              resources = {
                requests = {
                  memory = "128Mi"
                }
                limits = {
                  memory = "256Mi"
                }
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
                              "k8s-gateway",
                            ]
                          },
                        ]
                      }
                      topologyKey = "kubernetes.io/hostname"
                    },
                  ]
                }
              }
              priorityClassName = "system-cluster-critical"
              servers = [
                {
                  zones = [
                    {
                      zone    = "."
                      scheme  = "dns://"
                      use_tcp = true
                    },
                  ]
                  port = 53
                  plugins = concat([
                    {
                      name = "errors"
                    },
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
                      name        = "log"
                      configBlock = <<-EOF
                      class error
                      EOF
                    },
                    {
                      name       = "prometheus"
                      parameters = "0.0.0.0:${local.service_ports.coredns_metrics}"
                    },
                    {
                      name        = "k8s_gateway"
                      parameters  = "${local.domains.kubernetes} ${local.domains.public}"
                      configBlock = <<-EOF
                      resources Service HTTPRoute
                      fallthrough
                      EOF
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
                },
              ]
            }
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