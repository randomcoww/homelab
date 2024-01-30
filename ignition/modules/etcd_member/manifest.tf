locals {
  config_path        = "${var.config_base_path}/${var.name}"
  etcd_snapshot_file = "${local.config_path}/etcd-snapshot.db"
  etcd_manifest_file = "${var.static_pod_path}/etcd.json"

  # etcd cluster params
  initial_advertise_peer_urls = join(",", [
    for _, ip in var.etcd_ips :
    "https://${ip}:${var.ports.etcd_peer}"
  ])
  listen_peer_urls = join(",", [
    for _, ip in var.etcd_ips :
    "https://${ip}:${var.ports.etcd_peer}"
  ])
  advertise_client_urls = join(",", [
    for _, ip in var.etcd_ips :
    "https://${ip}:${var.ports.etcd_client}"
  ])
  listen_client_urls = join(",", [
    for _, ip in concat(["127.0.0.1"], var.etcd_ips) :
    "https://${ip}:${var.ports.etcd_client}"
  ])
  initial_cluster = join(",", [
    for host_key, ip in var.members :
    "${host_key}=https://${ip}:${var.ports.etcd_peer}"
  ])

  # etcd-wrapper access params
  initial_cluster_clients = join(",", [
    for host_key, ip in var.members :
    "${host_key}=https://${ip}:${var.ports.etcd_client}"
  ])

  pki = {
    for key, f in {
      ca-cert = {
        contents = var.ca.cert_pem
      }
      cert = {
        contents = tls_locally_signed_cert.etcd.cert_pem
      }
      key = {
        contents = tls_private_key.etcd.private_key_pem
      }
      peer-ca-cert = {
        contents = var.peer_ca.cert_pem
      }
      peer-cert = {
        contents = tls_locally_signed_cert.etcd-peer.cert_pem
      }
      peer-key = {
        contents = tls_private_key.etcd-peer.private_key_pem
      }
      client-cert = {
        contents = tls_locally_signed_cert.etcd-client.cert_pem
      }
      client-key = {
        contents = tls_private_key.etcd-client.private_key_pem
      }
    } :
    key => merge(f, {
      path = "${local.config_path}/${key}.pem"
    })
  }

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

  ignition_snippets = [
    yamlencode({
      variant = "fcos"
      version = var.ignition_version
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
    })
  ]
}

module "etcd-wrapper" {
  source = "../static_pod"
  name   = "etcd-wrapper"
  spec = {
    containers = [
      {
        name  = "etcd-wrapper"
        image = var.images.etcd_wrapper
        args = [
          # etcd args
          "--name=${var.host_key}",
          "--trusted-ca-file=${local.pki.ca-cert.path}",
          "--peer-trusted-ca-file=${local.pki.peer-ca-cert.path}",
          "--cert-file=${local.pki.cert.path}",
          "--key-file=${local.pki.key.path}",
          "--peer-cert-file=${local.pki.peer-cert.path}",
          "--peer-key-file=${local.pki.peer-key.path}",
          "--initial-advertise-peer-urls=${local.initial_advertise_peer_urls}",
          "--listen-peer-urls=${local.listen_peer_urls}",
          "--advertise-client-urls=${local.advertise_client_urls}",
          "--listen-client-urls=${local.listen_client_urls}",
          "--initial-cluster-token=${var.cluster_token}",
          "--initial-cluster=${local.initial_cluster}",
          "--auto-compaction-retention=${tostring(var.auto_compaction_retention)}",
          # pod manifest args
          "--etcd-image=${var.images.etcd}",
          "--etcd-snaphot-file=${local.etcd_snapshot_file}",
          "--etcd-pod-name=etcd",
          "--etcd-pod-namespace=$(POD_NAMESPACE)",
          "--etcd-pod-manifest-file=${local.etcd_manifest_file}",
          # etcd-wrapper args
          "--client-cert-file=${local.pki.client-cert.path}",
          "--client-key-file=${local.pki.client-key.path}",
          "--initial-cluster-clients=${local.initial_cluster_clients}",
          "--s3-backup-resource=${var.s3_resource}",
          "--healthcheck-interval=${var.healthcheck_interval}",
          "--backup-interval=${var.backup_interval}",
          "--healthcheck-fail-count-allowed=${var.healthcheck_fail_count_allowed}",
          "--readiness-fail-count-allowed=${var.readiness_fail_count_allowed}",
        ]
        env = [
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
          {
            name  = "AWS_DEFAULT_REGION"
            value = var.s3_region
          },
          {
            name  = "AWS_SDK_LOAD_CONFIG"
            value = "1"
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
            readOnly  = true
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