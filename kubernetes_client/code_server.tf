resource "tls_private_key" "code-jfs-metadata-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "code-jfs-metadata-ca" {
  private_key_pem = tls_private_key.code-jfs-metadata-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = "code"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

module "code-jfs-metadata" {
  source                   = "./modules/cockroachdb"
  cluster_service_endpoint = local.kubernetes_services.code_jfs_metadata.fqdn
  release                  = "0.1.0"
  replicas                 = 3
  images = {
    cockroachdb = local.container_images.cockroachdb
  }
  ports = {
    cockroachdb = local.service_ports.cockroachdb
  }
  ca = {
    algorithm       = tls_private_key.code-jfs-metadata-ca.algorithm
    private_key_pem = tls_private_key.code-jfs-metadata-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.code-jfs-metadata-ca.cert_pem
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

module "jupyter" {
  source  = "./modules/code_server"
  name    = "jupyter"
  release = "0.1.1"
  images = {
    code_server = local.container_images.jupyter
    jfs         = local.container_images.jfs
  }
  user                      = local.users.client.name
  uid                       = local.users.client.uid
  code_server_extra_configs = []
  code_server_extra_envs = [
    {
      name  = "MC_HOST_m"
      value = "http://${data.terraform_remote_state.sr.outputs.minio.access_key_id}:${data.terraform_remote_state.sr.outputs.minio.secret_access_key}@${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"
    },
  ]
  code_server_resources = {
    limits = {
      "nvidia.com/gpu" = 1
    }
  }
  code_server_security_context = {
    capabilities = {
      add = [
        "AUDIT_WRITE",
      ]
    }
  }
  service_hostname          = local.kubernetes_ingress_endpoints.jupyter
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations

  jfs_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_resource          = "${local.minio_buckets.jfs.name}/code"
  jfs_minio_endpoint          = "${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"
  jfs_metadata_ca = {
    algorithm       = tls_private_key.code-jfs-metadata-ca.algorithm
    private_key_pem = tls_private_key.code-jfs-metadata-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.code-jfs-metadata-ca.cert_pem
  }
  jfs_metadata_endpoint = "${local.kubernetes_services.code_jfs_metadata.endpoint}:${local.service_ports.cockroachdb}"
}