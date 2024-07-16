resource "tls_private_key" "mpd-jfs-metadata-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "mpd-jfs-metadata-ca" {
  private_key_pem = tls_private_key.mpd-jfs-metadata-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = "mpd"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

module "mpd-jfs-metadata" {
  source                   = "./modules/cockroachdb"
  cluster_service_endpoint = local.kubernetes_services.mpd_jfs_metadata.fqdn
  release                  = "0.1.0"
  replicas                 = 3
  images = {
    cockroachdb = local.container_images.cockroachdb
  }
  ports = {
    cockroachdb = local.service_ports.cockroachdb
  }
  ca = {
    algorithm       = tls_private_key.mpd-jfs-metadata-ca.algorithm
    private_key_pem = tls_private_key.mpd-jfs-metadata-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.mpd-jfs-metadata-ca.cert_pem
  }
  extra_configs = {
    store = "/data"
  }
  extra_volume_mounts = [
    {
      name      = "data"
      mountPath = "/data"
    },
  ]
  volume_claim_templates = [
    {
      metadata = {
        name = "data"
      }
      spec = {
        accessModes = [
          "ReadWriteOnce",
        ]
        resources = {
          requests = {
            storage = "4Gi"
          }
        }
        storageClassName = "local-path"
      }
    },
  ]
}

module "mpd" {
  source  = "./modules/mpd"
  name    = "mpd"
  release = "0.1.0"
  images = {
    mpd        = local.container_images.mpd
    mympd      = local.container_images.mympd
    rclone     = local.container_images.rclone
    litestream = local.container_images.litestream
    jfs        = local.container_images.jfs
  }
  extra_configs = {
    metadata_to_use = "AlbumArtist,Artist,Album,Title,Track,Disc,Genre,Name,Date"
  }
  service_hostname          = local.kubernetes_ingress_endpoints.mpd
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations

  data_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  data_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  data_minio_bucket            = local.minio_buckets.music.name
  data_minio_endpoint          = "${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"

  jfs_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_resource          = "${local.minio_buckets.jfs.name}/mpd"
  jfs_minio_endpoint          = "${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  jfs_metadata_ca = {
    algorithm       = tls_private_key.mpd-jfs-metadata-ca.algorithm
    private_key_pem = tls_private_key.mpd-jfs-metadata-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.mpd-jfs-metadata-ca.cert_pem
  }
  jfs_metadata_endpoint = "${local.kubernetes_services.mpd_jfs_metadata.endpoint}:${local.service_ports.cockroachdb}"
}