module "minio-metrics-proxy" {
  source  = "../../../modules/configmap"
  name    = "${var.name}-proxy"
  app     = var.name
  release = var.release
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