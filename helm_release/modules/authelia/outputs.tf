output "releases" {
  value = [
    for _, m in [
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = "${var.name}-resources"
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart = "helm-wrapper"
              sourceRef = {
                kind      = "HelmRepository"
                name      = "wrapper"
                namespace = "flux-runners"
              }
              interval = "5m"
            }
          }
          releaseName = "${var.name}-resources"
          install = {
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
            manifests = [
              module.secret.manifest,
              module.ldap-tls.manifest,
              module.redis-tls.manifest,
            ]
          }
        }
      },

      # main
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "https://charts.authelia.com"
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart   = "authelia"
              version = "0.10.58" # renovate: datasource=helm depName=authelia registryUrl=https://charts.authelia.com
              sourceRef = {
                kind = "HelmRepository"
                name = var.name
              }
              interval = "5m"
            }
          }
          releaseName = var.name
          install = {
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
            ## manifest start ##
            image = {
              registry   = var.images.authelia.registry
              repository = var.images.authelia.repository
              tag        = var.images.authelia.tag
            }
            service = {
              type = "ClusterIP"
              annotations = {
                "prometheus.io/scrape" = "true"
                "prometheus.io/port"   = tostring(var.ports.metrics)
              }
            }
            ingress = {
              enabled = true
              gatewayAPI = {
                enabled = true
                parentRefs = [
                  var.gateway_ref,
                ]
              }
            }
            pod = {
              replicas = 1
              kind     = "StatefulSet"
              selectors = {
                affinity = var.affinity
              }
              annotations = {
                "checksum/secret" = sha256(module.secret.manifest)
                "checksum/tls"    = sha256(module.ldap-tls.manifest)
              }
              extraVolumeMounts = [
                {
                  name      = var.name # this is mounted automatically if persistance is enabled
                  mountPath = dirname(local.authelia_db_file)
                },
                {
                  name      = "ca-trust-bundle"
                  mountPath = "/etc/ssl/certs/ca-certificates.crt"
                  readOnly  = true
                },
                {
                  name      = "authelia-ldap-tls"
                  mountPath = local.authelia_ldap_tls_cert_file
                  subPath   = "tls.crt"
                  readOnly  = true
                },
                {
                  name      = "authelia-ldap-tls"
                  mountPath = local.authelia_ldap_tls_key_file
                  subPath   = "tls.key"
                  readOnly  = true
                },
                {
                  name      = "authelia-redis-tls"
                  mountPath = local.authelia_redis_tls_cert_file
                  subPath   = "tls.crt"
                  readOnly  = true
                },
                {
                  name      = "authelia-redis-tls"
                  mountPath = local.authelia_redis_tls_key_file
                  subPath   = "tls.key"
                  readOnly  = true
                },
                {
                  name      = "oidc-client-share"
                  mountPath = local.autehlia_oidc_client_shared_path
                },
                {
                  name      = "secret-custom"
                  mountPath = local.authelia_oidc_hmac_secret_file
                  subPath   = "oidc-hmac-secret"
                  readOnly  = true
                },
                {
                  name      = "secret-custom"
                  mountPath = local.authelia_oidc_jwk_key_file
                  subPath   = "oidc-jwk-key"
                  readOnly  = true
                },
              ]
              extraVolumes = [
                {
                  name = var.name # remove if persistance is enabled
                  emptyDir = {
                    medium = "Memory"
                  }
                },
                {
                  name = "secret-custom"
                  secret = {
                    secretName = module.secret.name
                  }
                },
                {
                  name = "oidc-client-share"
                  emptyDir = {
                    medium = "Memory"
                  }
                },
                {
                  name = "ca-trust-bundle"
                  hostPath = {
                    path = "/etc/ssl/certs/ca-certificates.crt"
                    type = "File"
                  }
                },
                {
                  name = "authelia-ldap-tls"
                  secret = {
                    secretName = module.ldap-tls.name
                  }
                },
                {
                  name = "authelia-redis-tls"
                  secret = {
                    secretName = module.redis-tls.name
                  }
                },
              ]
              env = [
                {
                  name  = "AUTHELIA_AUTHENTICATION_BACKEND_LDAP_TLS_PRIVATE_KEY_FILE"
                  value = local.authelia_ldap_tls_key_file
                },
                {
                  name  = "AUTHELIA_AUTHENTICATION_BACKEND_LDAP_TLS_CERTIFICATE_CHAIN_FILE"
                  value = local.authelia_ldap_tls_cert_file
                },
                {
                  name  = "AUTHELIA_SESSION_REDIS_TLS_PRIVATE_KEY_FILE"
                  value = local.authelia_redis_tls_key_file
                },
                {
                  name  = "AUTHELIA_SESSION_REDIS_TLS_CERTIFICATE_CHAIN_FILE"
                  value = local.authelia_redis_tls_cert_file
                },
                {
                  name  = "AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE"
                  value = local.authelia_oidc_hmac_secret_file
                },
              ]
              initContainers = [
                {
                  name  = "${var.name}-password-generate"
                  image = "${var.images.authelia.registry}/${var.images.authelia.repository}:${var.images.authelia.tag}"
                  command = [
                    "sh",
                    "-c",
                    <<-EOF
                    %{~for key, v in var.oidc_clients~}
                    authelia crypto hash generate \
                      --password "$${OIDC_CLIENT_SECRET_${v.client_id}}" pbkdf2 | sed -e 's/Digest: //' > "${local.autehlia_oidc_client_shared_path}/client-secret-${key}"
                    %{~endfor~}
                    EOF
                  ]
                  env = [
                    for key, v in var.oidc_clients :
                    {
                      name = "OIDC_CLIENT_SECRET_${v.client_id}"
                      valueFrom = {
                        secretKeyRef = {
                          name = module.secret.name
                          key  = "oidc-client-secret-${key}"
                        }
                      }
                    }
                  ]
                  volumeMounts = [
                    {
                      name      = "oidc-client-share"
                      mountPath = local.autehlia_oidc_client_shared_path
                    },
                  ]
                },
                {
                  name  = "${var.name}-litestream-restore"
                  image = var.images.litestream
                  args = [
                    "restore",
                    "-if-db-not-exists",
                    "-if-replica-exists",
                    "-config",
                    local.authelia_litestream_config_file,
                    local.authelia_db_file,
                  ]
                  env = [
                    {
                      name = "POD_NAME"
                      valueFrom = {
                        fieldRef = {
                          fieldPath = "metadata.name"
                        }
                      }
                    },
                    {
                      name = "AWS_ACCESS_KEY_ID"
                      valueFrom = {
                        secretKeyRef = {
                          name = var.minio_access_secret
                          key  = "AWS_ACCESS_KEY_ID"
                        }
                      }
                    },
                    {
                      name = "AWS_SECRET_ACCESS_KEY"
                      valueFrom = {
                        secretKeyRef = {
                          name = var.minio_access_secret
                          key  = "AWS_SECRET_ACCESS_KEY"
                        }
                      }
                    },
                  ]
                  volumeMounts = [
                    {
                      name      = var.name
                      mountPath = dirname(local.authelia_db_file)
                    },
                    {
                      name      = "secret-custom"
                      mountPath = local.authelia_litestream_config_file
                      subPath   = "litestream"
                    },
                    {
                      name      = "ca-trust-bundle"
                      mountPath = "/etc/ssl/certs/ca-certificates.crt"
                      readOnly  = true
                    },
                  ]
                },
                {
                  name          = "${var.name}-litestream-replicate"
                  image         = var.images.litestream
                  restartPolicy = "Always"
                  args = [
                    "replicate",
                    "-config",
                    local.authelia_litestream_config_file,
                  ]
                  env = [
                    {
                      name = "POD_NAME"
                      valueFrom = {
                        fieldRef = {
                          fieldPath = "metadata.name"
                        }
                      }
                    },
                    {
                      name = "AWS_ACCESS_KEY_ID"
                      valueFrom = {
                        secretKeyRef = {
                          name = var.minio_access_secret
                          key  = "AWS_ACCESS_KEY_ID"
                        }
                      }
                    },
                    {
                      name = "AWS_SECRET_ACCESS_KEY"
                      valueFrom = {
                        secretKeyRef = {
                          name = var.minio_access_secret
                          key  = "AWS_SECRET_ACCESS_KEY"
                        }
                      }
                    },
                  ]
                  volumeMounts = [
                    {
                      name      = var.name
                      mountPath = dirname(local.authelia_db_file)
                    },
                    {
                      name      = "secret-custom"
                      mountPath = local.authelia_litestream_config_file
                      subPath   = "litestream"
                    },
                    {
                      name      = "ca-trust-bundle"
                      mountPath = "/etc/ssl/certs/ca-certificates.crt"
                      readOnly  = true
                    },
                  ]
                  resources = {
                    requests = {
                      memory = "1Gi"
                    }
                    limits = {
                      memory = "2Gi"
                    }
                  }
                },
              ]
              resources = {
                requests = {
                  memory = "128Mi"
                }
                limits = {
                  memory = "128Mi"
                }
              }
            }
            configMap = {
              log = {
                level = "debug"
              }
              telemetry = {
                metrics = {
                  enabled = true
                  port    = var.ports.metrics
                }
              }
              default_2fa_method = "webauthn"
              theme              = "dark"
              totp = {
                disable = true
              }
              webauthn = {
                disable = false
              }
              identity_validation = {
                reset_password = {
                  secret = {
                    value = random_bytes.authelia-jwt-secret.base64
                  }
                }
              }
              authentication_backend = {
                password_reset = {
                  disable = true
                }
                # https://github.com/lldap/lldap/blob/main/example_configs/authelia_config.yml
                ldap = {
                  enabled        = true
                  implementation = "custom"
                  tls = {
                    skip_verify     = false
                    minimum_version = "TLS1.3"
                  }
                  address = "ldaps://${var.ldap_endpoint}"
                  base_dn = "dc=${join(",dc=", split(".", regex(local.domain_regex, var.ldap_endpoint).domain))}"
                  attributes = {
                    username     = "uid"
                    mail         = "mail"
                    group_name   = "cn"
                    display_name = "displayName"
                  }
                  additional_users_dn  = "ou=people"
                  users_filter         = "(&({username_attribute}={input})(objectClass=person))"
                  additional_groups_dn = "ou=groups"
                  groups_filter        = "(member={dn})"
                  user                 = "uid=${var.ldap_credentials.username},ou=people,dc=${join(",dc=", split(".", regex(local.domain_regex, var.ldap_endpoint).domain))}"
                  password = {
                    value = var.ldap_credentials.password
                  }
                }
                file = {
                  enabled = false
                }
              }
              identity_providers = {
                oidc = {
                  enabled = true
                  hmac_secret = {
                    disabled = true
                  }
                  jwks = [
                    {
                      use = "sig"
                      key = {
                        path = local.authelia_oidc_jwk_key_file
                      }
                    },
                  ]
                  claims_policies = var.oidc_claims_policies
                  cors = {
                    endpoints = [
                      "token",
                      "authorization",
                    ]
                    allowed_origins_from_client_redirect_uris = true
                  },
                  enable_client_debug_messages = true
                  clients = [
                    for key, client in var.oidc_clients :
                    merge({
                      public                           = false
                      authorization_policy             = "two_factor"
                      require_pkce                     = true
                      pkce_challenge_method            = "S256"
                      access_token_signed_response_alg = "RS256"
                      token_endpoint_auth_method       = "client_secret_basic"
                      }, {
                      for k, v in client :
                      k => v
                      if k != "client_secret"
                      }, lookup(client, "public", false) ? {} : {
                      client_secret = {
                        path = "${local.autehlia_oidc_client_shared_path}/client-secret-${key}"
                      }
                    })
                  ]
                }
              }
              session = {
                inactivity  = "4h"
                expiration  = "4h"
                remember_me = 0
                encryption_key = {
                  value = random_password.authelia-session-encryption-key.result
                }
                cookies = [
                  {
                    domain    = regex(local.domain_regex, var.ingress_hostname).domain
                    subdomain = regex(local.domain_regex, var.ingress_hostname).subdomain
                  },
                ]
                redis = {
                  enabled = true
                  host    = var.redis_sentinel_endpoint.host
                  port    = var.redis_sentinel_endpoint.port
                  password = {
                    disabled = true
                  }
                  tls = {
                    enabled = true
                  }
                  high_availability = {
                    enabled       = true
                    sentinel_name = var.redis_sentinel_endpoint.master_name
                    password = {
                      disabled = true
                    }
                  }
                }
              }
              regulation = {
                max_retries = 4
              }
              storage = {
                encryption_key = {
                  value = random_password.authelia-storage-secret.result
                }
                local = {
                  enabled = true
                  path    = local.authelia_db_file
                }
              }
              notifier = {
                disable_startup_check = true
                smtp = {
                  enabled  = true
                  address  = "submission://${var.smtp.host}:${var.smtp.port}"
                  username = var.smtp.username
                  sender   = var.smtp.username
                  password = {
                    value = var.smtp.password
                  }
                }
              }
              access_control = {
                default_policy = "two_factor"
              }
            }
            certificates = {
              values = [
                {
                  name  = "ldap-ca.pem"
                  value = var.ldap_ca.cert_pem
                },
                {
                  name  = "redis-ca.pem"
                  value = var.redis_ca.cert_pem
                },
              ]
            }
            secret = {
              additionalSecrets = {
              }
            }
            persistence = {
              enabled = false
              /* persistent path for sqlite - remove extraVolumeMounts and extraVolumes entries if enabled
              enabled      = true
              storageClass = "local-path"
              accessModes = [
                "ReadWriteOnce",
              ]
              */
            }
          }
        }
      },
    ] :
    yamlencode(m)
  ]
}