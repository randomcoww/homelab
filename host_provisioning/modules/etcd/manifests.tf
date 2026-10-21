locals {
  config_path                  = "${var.config_base_path}/${var.name}"
  etcd_wrapper_path            = "/etcd-wrapper"
  check_quorum_timeout_seconds = 240

  env_config = {
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
    "ETCD_TRUSTED_CA_FILE"       = local.pki_files["ca.crt"].path
    "ETCD_CERT_FILE"             = local.pki_files["etcd.crt"].path
    "ETCD_KEY_FILE"              = local.pki_files["etcd.key"].path
    "ETCD_PEER_TRUSTED_CA_FILE"  = local.pki_files["etcd-peer-ca.crt"].path
    "ETCD_PEER_CERT_FILE"        = local.pki_files["etcd-peer.crt"].path
    "ETCD_PEER_KEY_FILE"         = local.pki_files["etcd-peer.key"].path
    "ETCD_LOG_LEVEL"             = "info"
    "ETCD_LOG_OUTPUTS"           = "stdout"
    "ETCD_LISTEN_METRICS_URLS"   = "http://127.0.0.1:${var.ports.etcd_metrics},http://$(POD_IP):${var.ports.etcd_metrics}"
    "ETCD_STRICT_RECONFIG_CHECK" = true
    "ETCD_SOCKET_REUSE_PORT"     = true
    "ETCD_SOCKET_REUSE_ADDRESS"  = true
  }

  config_files = {
    for key, f in {
      "etcd-wrapper-config.yaml" = yamlencode({
        etcdBinaryFile         = "/usr/local/bin/etcd"
        s3Endpoint             = var.s3_endpoint
        s3Bucket               = var.s3_bucket
        s3AccessKeyID          = var.s3_access_key_id
        s3SecretAccessKey      = var.s3_secret_access_key
        snapshotObjectPrefix   = var.s3_resource_prefix
        snapshotEncryptionKey  = var.snapshot_encryption_key
        checkQuorumTimeout     = "${local.check_quorum_timeout_seconds}s"
        backupInterval         = "10m"
        restoreSnapshotTimeout = "4m"
        uploadSnapshotTimeout  = "4m"
        snapshotTimeout        = "4m"
      })
    } :
    key => {
      mode = 384
      path = "${local.config_path}/${key}"
      contents = {
        inline = f
      }
    }
  }

  pki_files = {
    for key, f in {
      "ca.crt"           = var.ca.cert_pem
      "etcd.crt"         = tls_locally_signed_cert.kube-etcd.cert_pem
      "etcd.key"         = tls_private_key.kube-etcd.private_key_pem
      "etcd-peer-ca.crt" = var.peer_ca.cert_pem
      "etcd-peer.crt"    = tls_locally_signed_cert.kube-etcd-peer.cert_pem
      "etcd-peer.key"    = tls_private_key.kube-etcd-peer.private_key_pem
    } :
    key => {
      mode = 384
      path = "${local.config_path}/${key}"
      contents = {
        inline = f
      }
    }
  }
}

module "etcd-wrapper" {
  source    = "../../../modules/static-pod"
  name      = var.name
  namespace = var.namespace
  spec = {
    containers = [
      {
        name  = var.name
        image = "${var.images.etcd.repository}:${var.images.etcd.tag}"
        command = [
          "${local.etcd_wrapper_path}/bin/etcd-wrapper",
          "init",
          "-config",
          local.config_files["etcd-wrapper-config.yaml"].path,
        ]
        env = concat([
          {
            name = "POD_IP"
            valueFrom = {
              fieldRef = {
                fieldPath = "status.podIP"
              }
            }
          },
          ], [
          for k, v in local.env_config :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ])
        resources = {
          requests = {
            memory = "1Gi"
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
          timeoutSeconds   = 4
          failureThreshold = 6
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.etcd_metrics
            path   = "/readyz"
          }
          timeoutSeconds = 4
        }
        startupProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.etcd_metrics
            path   = "/readyz"
          }
          failureThreshold = 12 + ceil(local.check_quorum_timeout_seconds / 10)
        }
        volumeMounts = [
          {
            name      = "etcd-wrapper"
            mountPath = local.etcd_wrapper_path
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
      {
        name  = "backup"
        image = "${var.images.etcd-wrapper.repository}:${var.images.etcd-wrapper.tag}"
        args = [
          "backup",
          "-config",
          local.config_files["etcd-wrapper-config.yaml"].path,
        ]
        env = concat([
          {
            name = "POD_IP"
            valueFrom = {
              fieldRef = {
                fieldPath = "status.podIP"
              }
            }
          },
          ], [
          for k, v in local.env_config :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ])
        resources = {
          requests = {
            memory = "512Mi"
          }
        }
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
          },
        ]
      },
    ]
    volumes = [
      {
        name = "etcd-wrapper"
        image = {
          reference = "${var.images.etcd-wrapper.repository}:${var.images.etcd-wrapper.tag}"
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