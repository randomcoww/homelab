locals {
  nginx_ingress_annotations_common = {
    "nginx.ingress.kubernetes.io/http-snippet"      = <<-EOF
    map $http_upgrade $connection_upgrade {
      default upgrade;
      '' close;
    }
    EOF
    "nginx.ingress.kubernetes.io/server-snippet"    = <<-EOF
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-XSS-Protection "0" always;
    add_header Permissions-Policy "interest-cohort=()";
    add_header Pragma "no-cache";
    add_header Cache-Control "no-store";
    client_max_body_size 0;
    EOF
    "nginx.ingress.kubernetes.io/location-snippets" = <<-EOF
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Accept-Encoding gzip;
    chunked_transfer_encoding off;
    EOF
    "nginx.ingress.kubernetes.io/affinity"          = "cookie"
  }
}