locals {
  nginx_ingress_annotations = {
    "cert-manager.io/cluster-issuer"                = local.kubernetes.cert_issuer_prod
    "nginx.ingress.kubernetes.io/http-snippet"      = <<-EOF
    map $http_upgrade $connection_upgrade {
      default upgrade;
      '' close;
    }
    EOF
    "nginx.ingress.kubernetes.io/server-snippet"    = <<-EOF
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
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
  }

  nginx_ingress_auth_annotations = merge({
    "nginx.ingress.kubernetes.io/auth-method"           = "GET"
    "nginx.ingress.kubernetes.io/auth-url"              = "http://${local.kubernetes_services.authelia.endpoint}.svc.${local.domains.kubernetes}/api/authz/auth-request"
    "nginx.ingress.kubernetes.io/auth-signin"           = "https://${local.kubernetes_ingress_endpoints.auth}?rm=$request_method"
    "nginx.ingress.kubernetes.io/auth-response-headers" = "Remote-User,Remote-Name,Remote-Groups,Remote-Email"
    "nginx.ingress.kubernetes.io/auth-snippet"          = <<-EOF
    proxy_set_header X-Forwarded-Method $request_method;
    EOF
  }, local.nginx_ingress_annotations)

  ingress_tls_common = {
    secretName = "${local.domains.public}-tls"
    hosts = [
      "*.${local.domains.public}",
    ]
  }
}