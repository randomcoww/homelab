locals {
  cert_issuer_prod    = "letsencrypt-prod"
  cert_issuer_staging = "letsencrypt-staging"

  # https://www.authelia.com/overview/security/measures/
  nginx_ingress_annotations = {
    "cert-manager.io/cluster-issuer"                    = local.cert_issuer_prod
    "nginx.ingress.kubernetes.io/auth-method"           = "GET"
    "nginx.ingress.kubernetes.io/auth-url"              = "http://${local.kubernetes_service_endpoints.authelia}/api/verify"
    "nginx.ingress.kubernetes.io/auth-signin"           = "https://${local.kubernetes_ingress_endpoints.auth}?rm=$request_method"
    "nginx.ingress.kubernetes.io/auth-response-headers" = "Remote-User,Remote-Name,Remote-Groups,Remote-Email"
    "nginx.ingress.kubernetes.io/http-snippet"          = <<EOF
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}
EOF
    "nginx.ingress.kubernetes.io/auth-snippet"          = <<EOF
proxy_set_header X-Forwarded-Method $request_method;
EOF
    "nginx.ingress.kubernetes.io/server-snippet"        = <<EOF
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "0" always;
add_header Permissions-Policy "interest-cohort=()";
add_header Pragma "no-cache";
add_header Cache-Control "no-store";
client_max_body_size 0;
proxy_buffering off;
proxy_request_buffering off;
EOF
    "nginx.ingress.kubernetes.io/location-snippets"     = <<EOF
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
proxy_set_header Accept-Encoding gzip;
EOF
  }

  tls_wildcard = {
    secretName = "${local.domains.internal}-tls"
    hosts = [
      "*.${local.domains.internal}",
    ]
  }

  authelia = {
    backup_user   = "authelia"
    backup_bucket = "randomcoww-authelia"
    backup_path   = "sqlite"
  }

  vaultwarden = {
    backup_user   = "vw"
    backup_bucket = "randomcoww-vw"
    backup_path   = "sqlite"
  }

  s3_backup = {
    backup_user   = "backup"
    backup_bucket = "randomcoww-backup"
  }
}
