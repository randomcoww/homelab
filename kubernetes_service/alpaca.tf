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

resource "minio_s3_bucket" "alpaca-db" {
  bucket        = "alpaca-db"
  force_destroy = false
}

resource "minio_iam_user" "alpaca-db" {
  name          = "alpaca-db"
  force_destroy = true
}

resource "minio_iam_policy" "alpaca-db" {
  name = "alpaca-db"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.alpaca-db.arn,
          "${minio_s3_bucket.alpaca-db.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "alpaca-db" {
  user_name   = minio_iam_user.alpaca-db.id
  policy_name = minio_iam_policy.alpaca-db.id
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
  service_hostname        = local.kubernetes_ingress_endpoints.alpaca_db
  service_ip              = local.services.alpaca_db.ip
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"

  minio_endpoint          = "http://${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.alpaca-db.id
  minio_access_key_id     = minio_iam_user.alpaca-db.id
  minio_secret_access_key = minio_iam_user.alpaca-db.secret
  minio_clickhouse_prefix = "clickhouse"
  minio_jfs_prefix        = "$(POD_NAME)"
  minio_litestream_prefix = "$POD_NAME/litestream"
}