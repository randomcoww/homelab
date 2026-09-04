locals {
  inference-gateway_chat_models = [
    "qwen-3-8-27b",
    "granite-4-2-3b",
  ]
}

resource "random_password" "inference-gateway-api-key" {
  length           = 32
  override_special = "-_"
}

resource "minio_s3_object" "fluxcd-inference-gateway" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in concat([
        {
          apiVersion = "gateway.networking.k8s.io/v1"
          kind       = "Gateway"
          metadata = {
            name      = "${local.agentgateway_name}-proxy"
            namespace = local.agentgateway_namespace
            annotations = {
              "cert-manager.io/cluster-issuer" = local.cert_issuers.acme_prod
            }
          }
          spec = {
            gatewayClassName = "agentgateway"
            infrastructure = {
              parametersRef = {
                name  = "${local.agentgateway_name}-config"
                group = "agentgateway.dev"
                kind  = "AgentgatewayParameters"
              }
            }
            listeners = [
              {
                allowedRoutes = {
                  namespaces = {
                    from = "Same"
                  }
                }
                name     = "web"
                port     = 80
                protocol = "HTTP"
              },
              {
                allowedRoutes = {
                  namespaces = {
                    from = "All"
                  }
                }
                hostname = local.endpoints.agentgateway.hostname
                name     = "websecure"
                port     = 443
                protocol = "HTTPS"
                tls = {
                  mode = "Terminate"
                  certificateRefs = [
                    {
                      group = ""
                      name  = "${local.endpoints.agentgateway.hostname}-tls"
                    },
                  ]
                }
              },
            ]
          }
        },
        {
          apiVersion = "agentgateway.dev/v1alpha1"
          kind       = "AgentgatewayParameters"
          metadata = {
            name      = "${local.agentgateway_name}-config"
            namespace = local.agentgateway_namespace
          }
          spec = {
            deployment = {
              spec = {
                replicas = 2
              }
            }
          }
        },
        {
          apiVersion = "agentgateway.dev/v1alpha1"
          kind       = "AgentgatewayPolicy"
          metadata = {
            name      = "${local.agentgateway_name}-extract-model"
            namespace = local.agentgateway_namespace
          }
          spec = {
            targetRefs = [
              {
                group = "gateway.networking.k8s.io"
                kind  = "Gateway"
                name  = "${local.agentgateway_name}-proxy"
              },
            ]
            traffic = {
              phase = "PreRouting"
              transformation = {
                request = {
                  set = [
                    {
                      name  = "x-model"
                      value = "json(request.body).model"
                    },
                  ]
                }
              }
            }
          }
        },
        {
          apiVersion = "gateway.networking.k8s.io/v1"
          kind       = "HTTPRoute"
          metadata = {
            name      = local.agentgateway_name
            namespace = local.agentgateway_namespace
          }
          spec = {
            parentRefs = [
              {
                name      = "${local.agentgateway_name}-proxy"
                namespace = local.agentgateway_namespace
              }
            ]
            hostnames = [
              local.endpoints.agentgateway.hostname,
            ]
            rules = [
              for _, model in local.inference-gateway_chat_models :
              {
                matches = [
                  {
                    path = {
                      type  = "PathPrefix"
                      value = "/v1/chat"
                    }
                    headers = [
                      {
                        type  = "Exact"
                        name  = "x-model"
                        value = model
                      },
                    ]
                  },
                ]
                backendRefs = [
                  {
                    name      = "model-${model}"
                    namespace = local.llama-cpp_namespace
                    group     = "agentgateway.dev"
                    kind      = "AgentgatewayBackend"
                  }
                ]
              }
            ]
          }
        },
        {
          apiVersion = "gateway.networking.k8s.io/v1"
          kind       = "ReferenceGrant"
          metadata = {
            name      = "${local.agentgateway_name}-proxy"
            namespace = local.llama-cpp_namespace
          }
          spec = {
            from = [
              {
                group     = "gateway.networking.k8s.io"
                kind      = "HTTPRoute"
                namespace = local.agentgateway_namespace
              },
            ]
            to = [
              for _, model in local.inference-gateway_chat_models :
              {
                group = "agentgateway.dev"
                kind  = "AgentgatewayBackend"
                name  = "model-${model}"
              }
            ]
          }
        },
        ], [

        for _, model in local.inference-gateway_chat_models :
        {
          apiVersion = "v1"
          kind       = "Service"
          metadata = {
            name      = "model-${model}"
            namespace = local.llama-cpp_namespace
          }
          spec = {
            selector = {
              "model-${model}" = "true"
            }
            ports = [
              {
                port       = local.llama-cpp_port
                targetPort = local.llama-cpp_port
              },
            ]
          }
        }
        ], [

        for _, model in local.inference-gateway_chat_models :
        {
          apiVersion = "agentgateway.dev/v1alpha1"
          kind       = "AgentgatewayBackend"
          metadata = {
            name      = "model-${model}"
            namespace = local.llama-cpp_namespace
          }
          spec = {
            ai = {
              provider = {
                custom = {
                  model = model
                  backendRef = {
                    name = "model-${model}"
                    port = local.llama-cpp_port
                  }
                  formats = [
                    {
                      type = "Completions"
                    },
                  ]
                }
              }
            }
          }
        }
      ]) :
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
  object_name  = "inference-gateway/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

# outputs

output "inference-gateway-api-key" {
  value     = random_password.inference-gateway-api-key.result
  sensitive = true
}