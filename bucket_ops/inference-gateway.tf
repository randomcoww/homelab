locals {
  inference-gateway_chat_models = [
    "qwen-3-8-27b",
    "granite-4-2-3b",
  ]
  inference-gateway_audio_model = "whisper-large-v3-turbo"
}

resource "minio_s3_object" "fluxcd-inference-gateway" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in concat([

        # agentgateway endpoint
        {
          apiVersion = "gateway.networking.k8s.io/v1"
          kind       = "Gateway"
          metadata = {
            name      = "${local.agentgateway_name}-proxy"
            namespace = local.agentgateway_namespace
            annotations = {
              "cert-manager.io/cluster-issuer" = local.cert_issuers.ca_internal
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
          apiVersion = "agentgateway.dev/v1alpha1"
          kind       = "AgentgatewayPolicy"
          metadata = {
            name      = "${local.agentgateway_name}-buffer"
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
              buffer = {
                request = {
                  maxBytes = "16Mi"
                }
                response = {
                  maxBytes = "16Mi"
                }
              }
            }
          }
        },

        # route models and MCPs to gateway
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
            rules = concat([

              ## Models ##

              {
                matches = [
                  {
                    path = {
                      type  = "PathPrefix"
                      value = "/v1/audio"
                    }
                  },
                ]
                backendRefs = [
                  {
                    name      = "model-${local.inference-gateway_audio_model}"
                    namespace = local.llama-cpp_namespace
                    group     = "agentgateway.dev"
                    kind      = "AgentgatewayBackend"
                  },
                ]
              },
              ], [

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
                  },
                ]
              }

              ], [
              {
                matches = [
                  {
                    path = {
                      type  = "PathPrefix"
                      value = "/mcp"
                    }
                  },
                ]
                backendRefs = [
                  {
                    name      = "${local.agentgateway_name}-mcp"
                    namespace = local.agentgateway_namespace
                    group     = "agentgateway.dev"
                    kind      = "AgentgatewayBackend"
                  },
                ]
              },
            ])
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
              for _, model in concat(local.inference-gateway_chat_models, [local.inference-gateway_audio_model]) :
              {
                group = "agentgateway.dev"
                kind  = "AgentgatewayBackend"
                name  = "model-${model}"
              }
            ]
          }
        },
        ], [

        ## Models ##

        for _, model in concat(local.inference-gateway_chat_models, [local.inference-gateway_audio_model]) :
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
        ], [

        {
          apiVersion = "v1"
          kind       = "Secret"
          metadata = {
            name      = "${local.agentgateway_name}-api-key"
            namespace = local.llama-cpp_namespace
          }
          type = "Opaque"
          stringData = {
            Authorization = random_password.llama-cpp-api-key.result
          }
        },
        {
          apiVersion = "agentgateway.dev/v1alpha1"
          kind       = "AgentgatewayBackend"
          metadata = {
            name      = "model-${local.inference-gateway_audio_model}"
            namespace = local.llama-cpp_namespace
          }
          spec = {
            ai = {
              provider = {
                openai = {
                  model = local.inference-gateway_audio_model
                }
                host = "model-${local.inference-gateway_audio_model}.${local.llama-cpp_namespace}"
                port = local.llama-cpp_port
              }
            }
            policies = {
              ai = {
                routes = {
                  "/v1/audio/transcriptions" = "Passthrough"
                  "/v1/models"               = "Passthrough"
                  "*"                        = "Passthrough"
                }
              }
              auth = {
                secretRef = {
                  name = "${local.agentgateway_name}-api-key"
                }
              }
            }
          }
        },

        # MCP
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "Certificate"
          metadata = {
            name      = "${local.agentgateway_name}-mcp-client-tls"
            namespace = local.agentgateway_namespace
          }
          spec = {
            secretName = "${local.agentgateway_name}-mcp-client-tls"
            isCA       = false
            privateKey = {
              algorithm = "ECDSA"
              size      = 521
            }
            commonName = "${local.agentgateway_name}-mcp"
            usages = [
              "client auth",
            ]
            issuerRef = {
              name = local.cert_issuers.ca_internal
              kind = "ClusterIssuer"
            }
          }
        },
        {
          apiVersion = "agentgateway.dev/v1alpha1"
          kind       = "AgentgatewayBackend"
          metadata = {
            name      = "${local.agentgateway_name}-mcp"
            namespace = local.agentgateway_namespace
          }
          spec = {
            mcp = {
              targets = [
                {
                  name = local.victoria-metrics-mcp_name
                  static = {
                    host     = "${local.victoria-metrics-mcp_name}-victoria-metrics-mcp.${local.victoria-metrics_namespace}"
                    port     = local.victoria-metrics-mcp_port
                    path     = "/mcp"
                    protocol = "StreamableHTTP"
                  }
                },
                {
                  name = local.victoria-logs-mcp_name
                  static = {
                    host     = "${local.victoria-logs-mcp_name}-victoria-logs-mcp.${local.victoria-metrics_namespace}"
                    port     = local.victoria-logs-mcp_port
                    path     = "/mcp"
                    protocol = "StreamableHTTP"
                  }
                },
                {
                  name = local.kubernetes-mcp_name
                  static = {
                    host     = "${local.kubernetes-mcp_name}.${local.kubernetes-mcp_namespace}"
                    port     = local.kubernetes-mcp_port
                    path     = "/mcp"
                    protocol = "StreamableHTTP"
                    policies = {
                      tls = {
                        sni = "${local.kubernetes-mcp_name}.${local.kubernetes-mcp_namespace}"
                        caCertificateRefs = [
                          {
                            kind = "Secret"
                            name = "${local.agentgateway_name}-mcp-client-tls"
                          },
                        ]
                        mtlsCertificateRef = [
                          {
                            kind = "Secret"
                            name = "${local.agentgateway_name}-mcp-client-tls"
                          },
                        ]
                      }
                    }
                  }
                },
              ]
            }
          }
        },
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