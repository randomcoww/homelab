locals {
  config_path       = "${var.config_base_path}/${var.name}"
  etcd_wrapper_path = "/etcd-wrapper"

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
        image = var.images.etcd
        command = [
          "${local.etcd_wrapper_path}/bin/etcd-wrapper",
          "-local-client-url",
          "https://127.0.0.1:${var.ports.etcd_client}",
          "-etcd-binary-file",
          "/usr/local/bin/etcd",
          "-etcdutl-binary-file",
          "/usr/local/bin/etcdutl",
          "-s3-backup-resource-prefix",
          var.s3_resource_prefix,
          "-initial-cluster-timeout",
          "${var.initial_startup_delay_seconds}s",
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
            "ETCD_TRUSTED_CA_FILE"       = local.pki_files["ca.crt"].path
            "ETCD_CERT_FILE"             = local.pki_files["etcd.crt"].path
            "ETCD_KEY_FILE"              = local.pki_files["etcd.key"].path
            "ETCD_PEER_TRUSTED_CA_FILE"  = local.pki_files["etcd-peer-ca.crt"].path
            "ETCD_PEER_CERT_FILE"        = local.pki_files["etcd-peer.crt"].path
            "ETCD_PEER_KEY_FILE"         = local.pki_files["etcd-peer.key"].path
            "ETCD_STRICT_RECONFIG_CHECK" = true
            "ETCD_LOG_LEVEL"             = "info"
            "ETCD_LISTEN_METRICS_URLS"   = "http://127.0.0.1:${var.ports.etcd_metrics},http://$(POD_IP):${var.ports.etcd_metrics}"
            "ETCD_SOCKET_REUSE_PORT"     = true
            "ETCD_SOCKET_REUSE_ADDRESS"  = true
            "AWS_ACCESS_KEY_ID"          = var.s3_access_key_id
            "AWS_SECRET_ACCESS_KEY"      = var.s3_secret_access_key
          } :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ])
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
          failureThreshold = 12 + ceil(var.initial_startup_delay_seconds / 10)
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
    ]
    volumes = [
      {
        name = "etcd-wrapper"
        image = {
          reference = var.images.etcd_wrapper
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