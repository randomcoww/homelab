locals {
  config_path     = "${var.config_base_path}/${var.name}"
  etcd_mount_path = "/etcd"
  pki = {
    for key, f in {
      ca-cert = {
        contents = var.ca.cert_pem
      }
      cert = {
        contents = tls_locally_signed_cert.kube-etcd.cert_pem
      }
      key = {
        contents = tls_private_key.kube-etcd.private_key_pem
      }
      peer-ca-cert = {
        contents = var.peer_ca.cert_pem
      }
      peer-cert = {
        contents = tls_locally_signed_cert.kube-etcd-peer.cert_pem
      }
      peer-key = {
        contents = tls_private_key.kube-etcd-peer.private_key_pem
      }
    } :
    key => merge(f, {
      path = "${local.config_path}/${key}.pem"
    })
  }
  initial_startup_delay_seconds = 120

  static_pod = {
    for key, f in {
      etcd-wrapper = {
        contents = module.etcd-wrapper.manifest
      }
    } :
    key => merge(f, {
      path = "${var.static_pod_path}/${key}.yaml"
    })
  }

  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      butane_version = var.butane_version
      name           = var.name
      fw_mark        = var.fw_mark
      ports          = var.ports
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.butane_version
      storage = {
        files = [
          for _, f in concat(
            values(local.pki),
            values(local.static_pod),
          ) :
          merge({
            mode = 384
            }, f, {
            contents = {
              inline = f.contents
            }
          })
        ]
      }
    }),
  ])

  pod_manifests = [
    for pod in local.static_pod :
    pod.contents
  ]
}

module "etcd-wrapper" {
  source    = "../../../modules/static_pod"
  name      = var.name
  namespace = var.namespace
  annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = tostring(var.ports.etcd_metrics)
  }
  spec = {
    containers = [
      {
        name  = "${var.name}-wrapper"
        image = var.images.etcd_wrapper
        args = [
          "-local-client-url",
          "https://127.0.0.1:${var.ports.etcd_client}",
          "-etcd-binary-file",
          "${local.etcd_mount_path}/usr/local/bin/etcd",
          "-etcdutl-binary-file",
          "${local.etcd_mount_path}/usr/local/bin/etcdutl",
          "-s3-backup-resource",
          var.s3_resource,
          "-initial-cluster-timeout",
          "${local.initial_startup_delay_seconds}s",
          "-node-run-interval",
          "10m",
        ]
        env = [
          for k, v in {
            "ETCD_NAME"                        = var.host_key
            "ETCD_DATA_DIR"                    = "${var.data_storage_path}/data"
            "ETCD_LISTEN_PEER_URLS"            = "https://127.0.0.1:${var.ports.etcd_peer},https://${var.node_ip}:${var.ports.etcd_peer}"
            "ETCD_INITIAL_ADVERTISE_PEER_URLS" = "https://${var.node_ip}:${var.ports.etcd_peer}"
            "ETCD_LISTEN_CLIENT_URLS"          = "https://127.0.0.1:${var.ports.etcd_client},https://${var.node_ip}:${var.ports.etcd_client}"
            "ETCD_ADVERTISE_CLIENT_URLS"       = "https://${var.node_ip}:${var.ports.etcd_client}"
            "ETCD_INITIAL_CLUSTER" = join(",", [
              for host_key, ip in var.members :
              "${host_key}=https://${ip}:${var.ports.etcd_peer}"
            ])
            "ETCD_INITIAL_CLUSTER_TOKEN" = var.cluster_token
            "ETCD_TRUSTED_CA_FILE"       = local.pki.ca-cert.path
            "ETCD_CERT_FILE"             = local.pki.cert.path
            "ETCD_KEY_FILE"              = local.pki.key.path
            "ETCD_PEER_TRUSTED_CA_FILE"  = local.pki.peer-ca-cert.path
            "ETCD_PEER_CERT_FILE"        = local.pki.peer-cert.path
            "ETCD_PEER_KEY_FILE"         = local.pki.peer-key.path
            "ETCD_STRICT_RECONFIG_CHECK" = true
            "ETCD_LOG_LEVEL"             = "info"
            "ETCD_LISTEN_METRICS_URLS"   = "http://0.0.0.0:${var.ports.etcd_metrics}"
            "ETCD_SOCKET_REUSE_PORT"     = true
            "ETCD_SOCKET_REUSE_ADDRESS"  = true
            "AWS_ACCESS_KEY_ID"          = var.s3_access_key_id
            "AWS_SECRET_ACCESS_KEY"      = var.s3_secret_access_key
          } :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ]
        resources = {
          requests = {
            memory = "2Gi"
          }
          limits = {
            memory = "2Gi"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.etcd_metrics
            path   = "/livez"
          }
          timeoutSeconds   = 10
          failureThreshold = 6
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.etcd_metrics
            path   = "/readyz"
          }
          timeoutSeconds = 5
        }
        startupProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.etcd_metrics
            path   = "/readyz"
          }
          failureThreshold = 6 + ceil(local.initial_startup_delay_seconds / 10)
        }
        volumeMounts = [
          {
            name      = "etcd"
            mountPath = local.etcd_mount_path
          },
          {
            name      = "config"
            mountPath = local.config_path
          },
          {
            name      = "data"
            mountPath = var.data_storage_path
          },
        ]
      },
    ]
    volumes = [
      {
        name = "etcd"
        image = {
          reference  = var.images.etcd
          pullPolicy = "IfNotPresent"
        }
      },
      {
        name = "config"
        hostPath = {
          path = local.config_path
        }
      },
      {
        name = "data"
        # hostPath = {
        #   path = var.data_storage_path
        # }
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}