locals {
  qrcode_port = 8080
  config_file = "/var/www/index.html"
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

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/service.yaml"    = module.service.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/deployment.yaml" = module.deployment.manifest
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

module "ingress" {
  source             = "../../../modules/ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = module.service.name
          port    = local.qrcode_port
          path    = "/"
        },
      ]
    },
  ]
}

module "deployment" {
  source   = "../../../modules/deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  template_spec = {
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
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.qrcode_port
            path   = "/"
          }
        }
        livenessProbe = {
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