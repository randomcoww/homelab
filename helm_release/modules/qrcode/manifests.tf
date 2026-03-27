locals {
  qrcode_port = 8080
  config_file = "/var/www/index.html"

  manifests = concat([
    module.service.manifest,
    module.secret.manifest,
    module.httproute.manifest,
    module.deployment.manifest,
    ], [
    for _, m in [
      {
        apiVersion = "traefik.io/v1alpha1"
        kind       = "Middleware"
        metadata = {
          name = var.name
        }
        spec = {
          chain = {
            middlewares = [
              var.middleware_ref,
            ]
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    "index.html" = <<-EOF
    <!DOCTYPE html>
    <html>
    <head>
      <link href="lib/tailwind.min.css" rel="stylesheet" type="text/css" />
      <style>
        html,
        body,
        #app {
          height: 100vh;
          margin: 0;
          padding: 0;
          font-family: 'Inter', sans-serif;
        }
        svg {
          width: 256px;
          height: 256px;
        }
        .mwh {
          min-width: 380px;
          min-height: 290px;
        }
        a {
          color: rgb(34, 125, 230);
        }
        a:hover {
          color: rgb(0, 105, 224);
        }
      </style>
    </head>
    <body>
      <div class="w-full h-full bg-gray-800 absolute flex flex-row justify-center items-center">
        <div id="qrcode" class="m-2"></div>
      </div>
      <script src="lib/qrcode.min.js"></script>
      <script type="module">
        function genSvg(val) {
          return new QRCode({
            content: val,
            container: 'svg-viewbox',
            join: true,
            width: 2048,
            height: 2048,
          }).svg()
        }
        window.onload = () => {
          document.getElementById("qrcode").innerHTML = genSvg("${var.qrcode_value}")
        }
      </script>
    </body>
    </html>
    EOF
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "qrcode"
        port       = local.qrcode_port
        protocol   = "TCP"
        targetPort = local.qrcode_port
      },
    ]
  }
}

module "httproute" {
  source  = "../../../modules/httproute"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    parentRefs = [
      merge({
        kind = "Gateway"
      }, var.gateway_ref),
    ]
    hostnames = [
      var.ingress_hostname,
    ]
    rules = [
      {
        matches = [
          {
            path = {
              type  = "PathPrefix"
              value = "/"
            }
          },
        ]
        backendRefs = [
          {
            name = module.service.name
            port = local.qrcode_port
          },
        ]
        filters = [
          {
            type = "ExtensionRef"
            extensionRef = {
              group = "traefik.io"
              kind  = "Middleware"
              name  = var.name
            }
          },
        ]
      },
    ]
  }
}

module "deployment" {
  source   = "../../../modules/deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    resources = {
      requests = {
        memory = "32Mi"
      }
      limits = {
        memory = "32Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.qrcode
        args = [
          "-p",
          "0.0.0.0:${local.qrcode_port}",
        ]
        ports = [
          {
            containerPort = local.qrcode_port
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.qrcode_port
            path   = "/"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.qrcode_port
            path   = "/"
          }
        }
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_file
            subPath   = "index.html"
          },
        ]
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}