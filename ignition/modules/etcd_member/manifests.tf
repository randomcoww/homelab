locals {
  config_path            = "${var.config_base_path}/${var.name}"
  etcd_manifest_file     = "${var.static_pod_path}/${var.name}.json"
  etcd_snapshot_file     = "${local.config_path}/etcd-snapshot.db"
  etcd_pod_template_file = "${local.config_path}/etcd-template.yaml"

  # etcd cluster params
  initial_advertise_peer_urls = "https://${var.node_ip}:${var.ports.etcd_peer}"
  listen_peer_urls            = "https://${var.node_ip}:${var.ports.etcd_peer}"
  advertise_client_urls       = "https://${var.node_ip}:${var.ports.etcd_client}"
  listen_client_urls          = "https://${var.node_ip}:${var.ports.etcd_client}"
  initial_cluster = join(",", [
    for host_key, ip in var.members :
    "${host_key}=https://${ip}:${var.ports.etcd_peer}"
  ])

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
      client-cert = {
        contents = tls_locally_signed_cert.etcd-wrapper-etcd-client.cert_pem
      }
      client-key = {
        contents = tls_private_key.etcd-wrapper-etcd-client.private_key_pem
      }
    } :
    key => merge(f, {
      path = "${local.config_path}/${key}.pem"
    })
  }

  static_pod = merge({
    for key, f in {
      etcd-wrapper = {
        contents = module.etcd-wrapper.manifest
      }
    } :
    key => merge(f, {
      path = "${var.static_pod_path}/${key}.yaml"
    })
    }, {
    etcd = {
      contents = module.etcd.manifest
      path     = local.etcd_pod_template_file
    }
  })

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

module "etcd" {
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
        name  = "etcd"
        image = var.images.etcd
        env = [
          {
            name  = "ETCD_ENABLE_V2"
            value = "false"
          },
          {
            name  = "ETCD_STRICT_RECONFIG_CHECK"
            value = "true"
          },
          {
            name  = "ETCD_AUTO_COMPACTION_RETENTION"
            value = tostring(var.auto_compaction_retention)
          },
          {
            name  = "ETCD_AUTO_COMPACTION_MODE"
            value = "revision"
          },
          {
            name  = "ETCD_LISTEN_METRICS_URLS"
            value = "http://0.0.0.0:${var.ports.etcd_metrics}"
          },
        ]
      },
    ]
  }
}

module "etcd-wrapper" {
  source    = "../../../modules/static_pod"
  name      = "${var.name}-wrapper"
  namespace = var.namespace
  spec = {
    containers = [
      {
        name  = "etcd-wrapper"
        image = var.images.etcd_wrapper
        args = [
          # etcd args
          "--name=${var.host_key}",
          "--cert-file=${local.pki.cert.path}",
          "--key-file=${local.pki.key.path}",
          "--trusted-ca-file=${local.pki.ca-cert.path}",
          "--peer-cert-file=${local.pki.peer-cert.path}",
          "--peer-key-file=${local.pki.peer-key.path}",
          "--peer-trusted-ca-file=${local.pki.peer-ca-cert.path}",
          "--initial-cluster-token=${var.cluster_token}",
          "--initial-advertise-peer-urls=${local.initial_advertise_peer_urls}",
          "--listen-peer-urls=${local.listen_peer_urls}",
          "--advertise-client-urls=${local.advertise_client_urls}",
          "--listen-client-urls=${local.listen_client_urls}",
          "--initial-cluster=${local.initial_cluster}",
          # etcd-wrapper args
          "--etcd-snaphot-file=${local.etcd_snapshot_file}",
          "--etcd-pod-template-file=${local.etcd_pod_template_file}",
          "--client-cert-file=${local.pki.client-cert.path}",
          "--client-key-file=${local.pki.client-key.path}",
          "--etcd-pod-manifest-write-path=${local.etcd_manifest_file}",
          "--s3-backup-endpoint=${var.s3_endpoint}",
          "--s3-backup-resource=${var.s3_resource}",
          "--healthcheck-interval=${var.healthcheck_interval}",
          "--backup-interval=${var.backup_interval}",
          "--healthcheck-fail-count-allowed=${var.healthcheck_fail_count_allowed}",
          "--readiness-fail-count-allowed=${var.readiness_fail_count_allowed}",
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
            name = "POD_NAMESPACE"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.namespace"
              }
            }
          },
          {
            name  = "AWS_ACCESS_KEY_ID"
            value = var.s3_access_key_id
          },
          {
            name  = "AWS_SECRET_ACCESS_KEY"
            value = var.s3_secret_access_key
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
          },
          {
            name      = "static-pod"
            mountPath = var.static_pod_path
          },
        ]
      },
    ]
    volumes = [
      {
        name = "config"
        hostPath = {
          path = local.config_path
        }
      },
      {
        name = "static-pod"
        hostPath = {
          path = var.static_pod_path
        }
      },
    ]
  }
}