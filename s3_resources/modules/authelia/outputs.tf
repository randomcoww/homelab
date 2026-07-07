output "manifests" {
  value = concat([
    module.secret.manifest,
    module.ldap-client-tls.manifest,
    module.redis-client-tls.manifest,
    ], [
    for _, m in [
      # database
      {
        apiVersion = "postgresql.cnpg.io/v1"
        kind       = "Cluster"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
        }
        spec = {
          instances = 3
          storage = {
            size = "2Gi"
          }
          bootstrap = {
            initdb = {
              database = "authelia"
              owner    = "authelia"
            }
          }
          resources = {
            requests = {
              memory = "256Mi"
            }
          }
        }
      },

      # authelia helm
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
              version = "0.11.6" # renovate: datasource=helm depName=authelia registryUrl=https://charts.authelia.com
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
                "prometheus.io/port"   = tostring(var.metrics_port)
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
              replicas = var.replicas
              kind     = "Deployment"
              selectors = {
                affinity = var.affinity
              }
              annotations = {
                "checksum/secret"           = sha256(module.secret.manifest)
                "checksum/ldap-client-tls"  = sha256(module.ldap-client-tls.manifest)
                "checksum/redis-client-tls" = sha256(module.redis-client-tls.manifest)
              }
              extraVolumeMounts = [
                {
                  name      = "ca-trust-bundle"
                  mountPath = "/etc/ssl/certs/ca-certificates.crt"
                  readOnly  = true
                },
                {
                  name      = "oidc-client-share"
                  mountPath = local.autehlia_oidc_client_shared_path
                },

                # custom
                {
                  name      = module.ldap-client-tls.name
                  mountPath = local.envs.AUTHELIA_AUTHENTICATION_BACKEND_LDAP_TLS_CERTIFICATE_CHAIN_FILE
                  subPath   = "tls.crt"
                  readOnly  = true
                },
                {
                  name      = module.ldap-client-tls.name
                  mountPath = local.envs.AUTHELIA_AUTHENTICATION_BACKEND_LDAP_TLS_PRIVATE_KEY_FILE
                  subPath   = "tls.key"
                  readOnly  = true
                },
                {
                  name      = module.redis-client-tls.name
                  mountPath = local.envs.AUTHELIA_SESSION_REDIS_TLS_CERTIFICATE_CHAIN_FILE
                  subPath   = "tls.crt"
                  readOnly  = true
                },
                {
                  name      = module.redis-client-tls.name
                  mountPath = local.envs.AUTHELIA_SESSION_REDIS_TLS_PRIVATE_KEY_FILE
                  subPath   = "tls.key"
                  readOnly  = true
                },
                {
                  name      = module.secret.name
                  mountPath = local.authelia_oidc_jwk_key_file
                  subPath   = "oidc-jwk-key"
                  readOnly  = true
                },
                {
                  name      = module.secret.name
                  mountPath = local.envs.AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE
                  subPath   = "oidc-hmac-secret"
                  readOnly  = true
                },
                {
                  name      = "${var.name}-pg-app"
                  mountPath = local.envs.AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE
                  subPath   = "password"
                  readOnly  = true
                },
              ]
              extraVolumes = [
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
                  name = module.ldap-client-tls.name
                  secret = {
                    secretName = module.ldap-client-tls.name
                  }
                },
                {
                  name = module.redis-client-tls.name
                  secret = {
                    secretName = module.redis-client-tls.name
                  }
                },
                {
                  name = module.secret.name
                  secret = {
                    secretName = module.secret.name
                  }
                },
                {
                  name = "${var.name}-pg-app"
                  secret = {
                    secretName = "${var.name}-pg-app"
                  }
                },
              ]
              env = concat([
                for k, v in local.envs :
                {
                  name  = tostring(k)
                  value = tostring(v)
                }
                ], [
                {
                  name = "AUTHELIA_STORAGE_POSTGRES_DATABASE"
                  valueFrom = {
                    secretKeyRef = {
                      name = "${var.name}-pg-app"
                      key  = "dbname"
                    }
                  }
                },
                {
                  name = "AUTHELIA_STORAGE_POSTGRES_USERNAME"
                  valueFrom = {
                    secretKeyRef = {
                      name = "${var.name}-pg-app"
                      key  = "username"
                    }
                  }
                },
                {
                  name = "postgres_host"
                  valueFrom = {
                    secretKeyRef = {
                      name = "${var.name}-pg-app"
                      key  = "host"
                    }
                  }
                },
                {
                  name = "postgres_port"
                  valueFrom = {
                    secretKeyRef = {
                      name = "${var.name}-pg-app"
                      key  = "port"
                    }
                  }
                },
                {
                  name  = "AUTHELIA_STORAGE_POSTGRES_ADDRESS"
                  value = "tcp://$(postgres_host).${var.namespace}:$(postgres_port)"
                },
              ])
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
                  port    = var.metrics_port
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
                postgres = {
                  enabled = true
                  deploy  = false
                  password = {
                    disabled = true # manually create and define AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE
                  }
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
            }
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}