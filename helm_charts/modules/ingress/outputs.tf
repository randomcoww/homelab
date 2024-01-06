output "manifest" {
  value = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name = var.name
      labels = {
        app     = var.app
        release = var.release
      }
      # https://www.authelia.com/overview/security/measures/
      annotations = merge({
        "cert-manager.io/cluster-issuer"                    = var.cert_issuer
        "nginx.ingress.kubernetes.io/auth-method"           = "GET"
        "nginx.ingress.kubernetes.io/auth-url"              = var.auth_url
        "nginx.ingress.kubernetes.io/auth-signin"           = var.auth_signin
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
EOF
        "nginx.ingress.kubernetes.io/location-snippets"     = <<EOF
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
proxy_set_header Accept-Encoding gzip;
EOF
      }, var.annotations)
    }
    spec = merge({
      ingressClassName = var.ingress_class_name
      rules = [
        for rule in var.rules :
        {
          host = rule.host
          http = {
            paths = [
              for path in rule.paths :
              {
                backend = {
                  service = {
                    name = path.service
                    port = {
                      number = path.port
                    }
                  }
                  path     = path.path
                  pathType = "Prefix"
                }
              }
            ]
          }
        }
      ]
      tls = [
        for wildcard_domain in distinct([
          for rule in var.rules :
          join(".", compact(slice(split(".", rule.host), 1, length(rule.host))))
        ]) :
        {
          secretName = "${wildcard_domain}-tls"
          hosts = [
            "*.${wildcard_domain}",
          ]
        }
      ]
      selector = {
        matchLabels = {
          app     = var.app
          release = var.release
        }
      }
    }, var.spec)
  })
}