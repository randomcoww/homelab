locals {
  juicefs_client_tls_path = "/var/tmp/juicefs"
}

resource "minio_s3_object" "fluxcd-juicefs-csi-driver" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "juicefs-csi-driver"
            namespace = "juicefs"
          }
          spec = {
            interval = "15m"
            url      = "https://juicedata.github.io/charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "juicefs-csi-driver"
            namespace = "juicefs"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "juicefs-csi-driver"
                version = "0.32.4" # renovate: datasource=helm depName=juicefs-csi-driver registryUrl=https://juicedata.github.io/charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "juicefs-csi-driver"
                }
                interval = "5m"
              }
            }
            releaseName = "juicefs-csi-driver"
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
              kubeletDir = local.kubernetes.kubelet_root_path
              node = {
                extraVolumes = [
                  {
                    name = "juicefs-metadata-client-tls"
                    secret = {
                      secretName = "juicefs-metadata-client-tls"
                    }
                  },
                ]
                extraVolumeMounts = [
                  {
                    name      = "juicefs-metadata-client-tls"
                    mountPath = local.juicefs_client_tls_path
                  },
                ]
              }
              metrics = {
                enabled = true
              }
              dashboard = {
                enabled = false
              }
              globalConfig = {
                enabled = true
                mountPodPatch = [
                  {
                    mountOptions = [
                      "no-syslog",
                      "atime-mode=noatime",
                      "backup-meta=0",
                      "no-usage-report=true",
                    ]
                    readinessProbe = {
                      exec = {
                        command = [
                          "stat",
                          "$${MOUNT_POINT}/$${SUB_PATH}",
                        ]
                      }
                      failureThreshold    = 3
                      initialDelaySeconds = 10
                      periodSeconds       = 5
                      successThreshold    = 1
                    }
                    resources = {
                      requests = {
                        memory = "128Mi"
                      }
                    }
                    volumes = [
                      {
                        name = "ca-trust-bundle"
                        hostPath = {
                          path = "/etc/ssl/certs/ca-certificates.crt"
                          type = "File"
                        }
                      },
                      {
                        name = "juicefs-metadata-client-tls"
                        secret = {
                          secretName = "juicefs-metadata-client-tls"
                        }
                      },
                    ]
                    volumeMounts = [
                      {
                        name      = "ca-trust-bundle"
                        mountPath = "/etc/ssl/certs/ca-certificates.crt"
                        readOnly  = true
                      },
                      {
                        name      = "juicefs-metadata-client-tls"
                        mountPath = local.juicefs_client_tls_path
                      },
                    ]
                  },
                  module.hermes-agent.juicefs-mountopts,
                  module.stump.juicefs-mountopts,
                ]
              }
            }
          }
        },

        # metadata client tls
        # this is mounted to both juicefs-node and mount container configured via configMap
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "Certificate"
          metadata = {
            name      = "juicefs-metadata-client-tls"
            namespace = "juicefs"
          }
          spec = {
            secretName = "juicefs-metadata-client-tls"
            isCA       = false
            privateKey = {
              algorithm = "ECDSA"
              size      = 521
            }
            commonName = "juicefs"
            usages = [
              "client auth",
            ]
            issuerRef = {
              name = local.cert_issuers.ca_internal
              kind = "ClusterIssuer"
            }
          }
        },

        # NS
        {
          apiVersion = "v1"
          kind       = "Namespace"
          metadata = {
            name = "juicefs"
            annotations = {
              "kustomize.toolkit.fluxcd.io/prune" = "disabled"
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
  object_name  = "juicefs-csi-driver/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}