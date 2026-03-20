resource "tls_private_key" "minio" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "minio" {
  private_key_pem = tls_private_key.minio.private_key_pem

  subject {
    common_name = var.name
  }
  ip_addresses = [
    "127.0.0.1",
    var.service_ip,
    var.cluster_service_ip,
  ]
  dns_names = concat([
    "localhost",
    var.name,
    ], [
    for i, _ in range(var.replicas) :
    "${var.name}-${i}.${var.name}-svc.${var.namespace}.svc"
  ])
}

resource "tls_locally_signed_cert" "minio" {
  cert_request_pem   = tls_cert_request.minio.cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
    "server_auth",
  ]
}

module "minio-tls" {
  source  = "../../../modules/secret"
  name    = "${var.name}-tls"
  app     = var.name
  release = "0.1.0"
  data = {
    "tls.crt" = tls_locally_signed_cert.minio.cert_pem
    "tls.key" = tls_private_key.minio.private_key_pem
    "ca.crt"  = var.ca.cert_pem
  }
}

module "minio-metrics-proxy" {
  source  = "../../../modules/configmap"
  name    = "${var.name}-proxy"
  app     = var.name
  release = "0.1.0"
  data = {
    "nginx-proxy.conf" = <<-EOF
    proxy_request_buffering off;
    proxy_buffering off;
    proxy_cache off;

    server {
      listen ${var.ports.metrics};
      location /minio/metrics/v3 {
        proxy_pass https://127.0.0.1:${var.ports.minio};

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }
    }
    EOF
  }
}