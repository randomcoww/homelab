module "alpaca-stream" {
  source    = "./modules/alpaca_stream"
  name      = local.kubernetes_services.alpaca_stream.name
  namespace = local.kubernetes_services.alpaca_stream.namespace
  release   = "0.1.1"
  images = {
    alpaca_stream = local.container_images.alpaca_stream
  }
  ports = {
    alpaca_stream = local.service_ports.alpaca_stream
  }
  service_hostname      = local.kubernetes_ingress_endpoints.alpaca_stream
  service_ip            = local.services.alpaca_stream.ip
  alpaca_api_key_id     = var.alpaca.api_key_id
  alpaca_api_secret_key = var.alpaca.api_secret_key
  alpaca_api_base_url   = var.alpaca.api_base_url
}

resource "tls_private_key" "alpaca-db-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "alpaca-db-ca" {
  private_key_pem = tls_private_key.alpaca-db-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = "alpaca-db"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

module "alpaca-db" {
  source                   = "./modules/clickhouse"
  cluster_service_endpoint = local.kubernetes_services.alpaca_db.fqdn
  release                  = "0.1.1"
  replicas                 = 3
  images = {
    clickhouse = local.container_images.clickhouse
    jfs        = local.container_images.jfs
    litestream = local.container_images.litestream
  }
  ca = {
    algorithm       = tls_private_key.alpaca-db-ca.algorithm
    private_key_pem = tls_private_key.alpaca-db-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.alpaca-db-ca.cert_pem
  }
  data_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  data_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  data_minio_bucket            = local.minio_buckets.clickhouse.name
  data_minio_endpoint          = "${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"

  service_hostname = local.kubernetes_ingress_endpoints.alpaca_db
  service_ip       = local.services.alpaca_db.ip

  jfs_minio_access_key_id            = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key        = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_bucket_endpoint          = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}/${local.minio_buckets.jfs.name}"
  litestream_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  litestream_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  litestream_minio_bucket_endpoint   = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}/${local.minio_buckets.litestream.name}"

}