## Hack to release custom charts as local chart

locals {
  modules_enabled = [
    # module.fuse-device-plugin,
    module.kvm-device-plugin,
    module.nvidia-driver,
    module.kea,
    module.matchbox,
    module.lldap,
    # module.vaultwarden,
    module.authelia-redis,
    module.authelia,
    module.tailscale,
    module.hostapd,
    module.qrcode-hostapd,
    module.alpaca-db,
    module.code,
    module.webdav-pictures,
    module.webdav-videos,
    module.audioserve,
    module.sunshine-desktop,
    module.satisfactory-server,
  ]
}

resource "helm_release" "wrapper" {
  for_each = {
    for m in local.modules_enabled :
    m.chart.name => m.chart
  }
  chart            = "../helm-wrapper"
  name             = each.key
  namespace        = each.value.namespace
  create_namespace = true
  wait             = false
  timeout          = 300
  max_history      = 2
  values = [
    yamlencode({
      manifests = values(each.value.manifests)
    }),
  ]
}

# nginx ingress #

resource "helm_release" "ingress-nginx" {
  for_each = local.ingress_classes

  name             = each.value
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = local.kubernetes_services[each.key].namespace
  create_namespace = true
  wait             = false
  version          = "4.12.0"
  max_history      = 2
  values = [
    yamlencode({
      controller = {
        kind = "DaemonSet"
        image = {
          digest       = ""
          digestChroot = ""
        }
        admissionWebhooks = {
          patch = {
            image = {
              digest = ""
            }
          }
        }
        ingressClassResource = {
          enabled         = true
          name            = each.value
          controllerValue = "k8s.io/${each.value}"
        }
        ingressClass = each.value
        service = {
          type              = "LoadBalancer"
          loadBalancerIP    = local.services[each.key].ip
          loadBalancerClass = "kube-vip.io/kube-vip-class"
        }
        allowSnippetAnnotations = true
        config = {
          # 4.12.0 annotations issue:
          # https://github.com/kubernetes/ingress-nginx/issues/12618
          annotations-risk-level  = "Critical"
          ignore-invalid-headers  = "off"
          proxy-body-size         = 0
          proxy-buffering         = "off"
          proxy-request-buffering = "off"
          ssl-redirect            = "true"
          use-forwarded-headers   = "true"
          keep-alive              = "false"
        }
        controller = {
          dnsConfig = {
            options = [
              {
                name  = "ndots"
                value = "2"
              },
            ]
          }
        }
      }
    }),
  ]
}

# cert-manager #

resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  timeout          = 600
  version          = "v1.17.0"
  max_history      = 2
  values = [
    yamlencode({
      deploymentAnnotations = {
        "certmanager.k8s.io/disable-validation" = "true"
      }
      installCRDs = true
      prometheus = {
        enabled = false
      }
      extraArgs = [
        "--dns01-recursive-nameservers-only",
        "--dns01-recursive-nameservers=${local.upstream_dns.ip}:53",
      ]
      podDnsConfig = {
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

resource "helm_release" "cert-issuer" {
  name        = "cert-issuer"
  chart       = "../helm-wrapper"
  namespace   = "cert-manager"
  wait        = false
  max_history = 2
  values = [
    yamlencode({
      manifests = [
        for m in [
          {
            apiVersion = "v1"
            kind       = "Secret"
            metadata = {
              name = "cloudflare-token"
            }
            stringData = {
              token = data.terraform_remote_state.sr.outputs.cloudflare_dns_api_token
            }
            type = "Opaque"
          },
          {
            apiVersion = "v1"
            kind       = "Secret"
            metadata = {
              name = local.kubernetes.cert_issuer_prod
            }
            stringData = {
              "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.private_key_pem)
            }
            type = "Opaque"
          },
          {
            apiVersion = "v1"
            kind       = "Secret"
            metadata = {
              name = local.kubernetes.cert_issuer_staging
            }
            stringData = {
              "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.staging_private_key_pem)
            }
            type = "Opaque"
          },
          {
            apiVersion = "cert-manager.io/v1"
            kind       = "ClusterIssuer"
            metadata = {
              name = local.kubernetes.cert_issuer_prod
            }
            spec = {
              acme = {
                server = "https://acme-v02.api.letsencrypt.org/directory"
                email  = data.terraform_remote_state.sr.outputs.letsencrypt.username
                privateKeySecretRef = {
                  name = local.kubernetes.cert_issuer_prod
                }
                disableAccountKeyGeneration = true
                solvers = [
                  {
                    dns01 = {
                      cloudflare = {
                        apiTokenSecretRef = {
                          name = "cloudflare-token"
                          key  = "token"
                        }
                      }
                    }
                    selector = {
                      dnsZones = [
                        local.domains.public,
                      ]
                    }
                  },
                ]
              }
            }
          },
          {
            apiVersion = "cert-manager.io/v1"
            kind       = "ClusterIssuer"
            metadata = {
              name = local.kubernetes.cert_issuer_staging
            }
            spec = {
              acme = {
                server = "https://acme-staging-v02.api.letsencrypt.org/directory"
                email  = data.terraform_remote_state.sr.outputs.letsencrypt.username
                privateKeySecretRef = {
                  name = local.kubernetes.cert_issuer_staging
                }
                disableAccountKeyGeneration = true
                solvers = [
                  {
                    dns01 = {
                      cloudflare = {
                        apiTokenSecretRef = {
                          name = "cloudflare-token"
                          key  = "token"
                        }
                      }
                    }
                    selector = {
                      dnsZones = [
                        local.domains.public,
                      ]
                    }
                  },
                ]
              }
            }
          },
        ] :
        yamlencode(m)
      ]
    }),
  ]
}

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

# nvidia device plugin #

resource "helm_release" "nvidia-device-plugin" {
  name        = "nvidia-device-plugin"
  repository  = "https://nvidia.github.io/k8s-device-plugin"
  chart       = "nvidia-device-plugin"
  namespace   = "kube-system"
  wait        = false
  version     = "0.17.0"
  max_history = 2
  values = [
    yamlencode({
      compatWithCPUManager = true
      priorityClassName    = "system-node-critical"
      nvidiaDriverRoot     = "/run/nvidia/driver"
      cdi = {
        nvidiaHookPath = "/usr/bin/nvidia-ctk"
      }
      gfd = {
        enabled = true
      }
      config = {
        # map = {
        #   default = yamlencode({
        #     version = "v1"
        #     sharing = {
        #       mps = {
        #         renameByDefault = true
        #         resources = [
        #           {
        #             name     = "nvidia.com/gpu"
        #             replicas = 2
        #           },
        #         ]
        #       }
        #     }
        #   })
        # }
      }
    }),
  ]
}

# Github actions runner #

resource "helm_release" "arc" {
  name             = "arc"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set-controller"
  namespace        = "arc-systems"
  create_namespace = true
  wait             = false
  version          = "0.10.1"
  max_history      = 2
  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "gha-runner-scale-set-controller"
      }
    }),
  ]
}

resource "minio_iam_user" "arc" {
  name          = "arc"
  force_destroy = true
}

resource "minio_iam_policy" "arc" {
  name = "arc"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.data["boot"].arn,
          "${minio_s3_bucket.data["boot"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "arc" {
  user_name   = minio_iam_user.arc.id
  policy_name = minio_iam_policy.arc.id
}

# ADR
# https://github.com/actions/actions-runner-controller/discussions/3152
# SETFCAP needed in runner workflow pod to build code-server and sunshine-desktop images
resource "helm_release" "arc-runner-hook-template" {
  name        = "arc-runner-hook-template"
  chart       = "../helm-wrapper"
  namespace   = "arc-runners"
  wait        = false
  max_history = 2
  values = [
    yamlencode({
      manifests = [
        yamlencode({
          apiVersion = "v1"
          kind       = "Secret"
          metadata = {
            name = "workflow-template"
          }
          stringData = {
            "workflow-podspec.yaml" = yamlencode({
              spec = {
                containers = [
                  {
                    name = "$job"
                    securityContext = {
                      capabilities = {
                        add = [
                          "SETFCAP",
                        ]
                      }
                    }
                    resources = {
                      requests = {
                        memory                    = "2Gi"
                        "devices.kubevirt.io/kvm" = "1"
                      }
                      limits = {
                        "devices.kubevirt.io/kvm" = "1"
                      }
                    }
                    env = [
                      {
                        name  = "MC_HOST_arc"
                        value = "http://${minio_iam_user.arc.id}:${minio_iam_user.arc.secret}@${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"
                      },
                    ]
                  },
                ]
              }
            })
          }
        }),
      ]
    })
  ]
}

resource "helm_release" "arc-runner-set" {
  for_each = toset([
    "etcd-wrapper",
    "kapprover",
    "tftpd-ipxe",
    "hostapd-noscan",
    "kea",
    "kvm-device-plugin",
    "mountpoint-s3",
    "s3fs",
    "k8s-control-plane",
    "kube-proxy",
    "steamcmd",
    "qrcode-generator",
    "code-server",
    "sunshine-desktop",
    "fedora-coreos-config-custom",
    "tailscale-nft",
    "nvidia-driver-container",
    "homelab",
  ])

  name             = "arc-runner-${each.key}"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set"
  namespace        = "arc-runners"
  create_namespace = true
  wait             = false
  version          = "0.10.1"
  max_history      = 2
  values = [
    yamlencode({
      githubConfigUrl = "https://github.com/randomcoww/${each.key}"
      githubConfigSecret = {
        github_token = var.github.arc_token
      }
      maxRunners = 1
      containerMode = {
        type = "kubernetes"
        kubernetesModeWorkVolumeClaim = {
          accessModes = [
            "ReadWriteOnce",
          ]
          storageClassName = "local-path"
          resources = {
            requests = {
              storage = "2Gi"
            }
          }
        }
      }
      template = {
        spec = {
          containers = [
            {
              name  = "runner"
              image = "ghcr.io/actions/actions-runner:latest"
              command = [
                "/home/runner/run.sh",
              ]
              env = [
                {
                  name  = "ACTIONS_RUNNER_CONTAINER_HOOK_TEMPLATE"
                  value = "/home/runner/config/workflow-podspec.yaml"
                },
              ]
              volumeMounts = [
                {
                  name      = "workflow-podspec-volume"
                  mountPath = "/home/runner/config/workflow-podspec.yaml"
                  subPath   = "workflow-podspec.yaml"
                },
              ]
            },
          ]
          volumes = [
            {
              name = "workflow-podspec-volume"
              secret = {
                secretName = "workflow-template"
              }
            },
          ]
        }
      }
      controllerServiceAccount = {
        namespace = "arc-systems"
        name      = "gha-runner-scale-set-controller"
      }
    }),
  ]
}

# cloudflare tunnel #

resource "helm_release" "cloudflare-tunnel" {
  name        = "cloudflare-tunnel"
  namespace   = "default"
  repository  = "https://cloudflare.github.io/helm-charts/"
  chart       = "cloudflare-tunnel"
  wait        = false
  version     = "0.3.2"
  max_history = 2
  values = [
    yamlencode({
      cloudflare = {
        account    = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.account_id
        tunnelName = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.name
        tunnelId   = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.id
        secret     = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.secret
        ingress = [
          {
            hostname = "*.${local.domains.public}"
            service  = "https://${local.kubernetes_services.ingress_nginx_external.endpoint}"
          },
        ]
      }
    }),
  ]
}

# prometheus #

resource "helm_release" "prometheus" {
  name             = "prometheus"
  namespace        = "prometheus"
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  wait             = false
  version          = "27.3.0"
  max_history      = 2
  values = [
    yamlencode({
      server = {
        persistentVolume = {
          enabled = false
        }
      }
      serverFiles = {
        "prometheus.yml" = {
          scrape_configs = [
            {
              job_name = "prometheus"
              static_configs = [
                {
                  targets = [
                    "localhost:9090",
                  ]
                },
              ]
            },
            {
              job_name = "kubernetes-apiservers"
              kubernetes_sd_configs = [
                {
                  role = "endpoints"
                },
              ]
              scheme = "https"
              tls_config = {
                ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
              }
              bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
              relabel_configs = [
                {
                  source_labels = [
                    "__meta_kubernetes_namespace",
                    "__meta_kubernetes_service_name",
                    "__meta_kubernetes_endpoint_port_name",
                  ]
                  action = "keep"
                  regex  = "default;kubernetes;https"
                },
              ]
            },
            {
              job_name = "kubernetes-nodes"
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
                  action = "labelmap"
                  regex  = "__meta_kubernetes_node_label_(.+)"
                },
                {
                  target_label = "__address__"
                  replacement  = "kubernetes.default.svc:443"
                },
                {
                  source_labels = [
                    "__meta_kubernetes_node_name",
                  ]
                  regex        = "(.+)"
                  target_label = "__metrics_path__"
                  replacement  = "/api/v1/nodes/$1/proxy/metrics"
                },
              ]
            },
            {
              job_name = "etcd"
              static_configs = [
                {
                  targets = [
                    for _, host in local.members.etcd :
                    "${cidrhost(local.networks.etcd.prefix, host.netnum)}:${local.host_ports.etcd_metrics}"
                  ]
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