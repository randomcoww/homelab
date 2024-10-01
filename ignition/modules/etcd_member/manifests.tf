locals {
  config_path        = "${var.config_base_path}/${var.name}"
  etcd_snapshot_file = "${local.config_path}/etcd-snapshot.db"
  etcd_manifest_file = "${var.static_pod_path}/${var.name}.json"

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
    for _, ip in var.etcd_ips :
    "https://${ip}:${var.ports.etcd_client}"
  ])
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
      ignition_version = var.ignition_version
      ports            = var.ports
    })
    ], [
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
  ])

  pod_manifests = [
    for pod in local.static_pod :
    pod.contents
  ]
}

module "etcd-wrapper" {
  source = "../../../modules/static_pod"
  name   = "${var.name}-wrapper"
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
          "--etcd-pod-name=${var.name}",
          "--etcd-pod-namespace=$(POD_NAMESPACE)",
          "--etcd-pod-manifest-file=${local.etcd_manifest_file}",
          # etcd-wrapper args
          "--client-cert-file=${local.pki.client-cert.path}",
          "--client-key-file=${local.pki.client-key.path}",
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