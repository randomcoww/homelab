locals {
  data_path   = "/var/lib/matchbox/mnt"
  config_path = "/etc/matchbox"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.matchbox)[1]
  manifests = merge(module.mountpoint.chart.manifests, {
    "templates/service.yaml"     = module.service.manifest
    "templates/service-api.yaml" = module.service-api.manifest
    "templates/secret.yaml"      = module.secret.manifest
  })
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    ca       = chomp(var.ca.cert_pem)
    api_cert = chomp(tls_locally_signed_cert.matchbox.cert_pem)
    api_key  = chomp(tls_private_key.matchbox.private_key_pem)
    web_cert = chomp(tls_locally_signed_cert.matchbox-web.cert_pem)
    web_key  = chomp(tls_private_key.matchbox-web.private_key_pem)
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type              = "LoadBalancer"
    loadBalancerIP    = var.service_ip
    loadBalancerClass = var.loadbalancer_class_name
    ports = [
      {
        name       = "matchbox"
        port       = var.ports.matchbox
        protocol   = "TCP"
        targetPort = var.ports.matchbox
      },
    ]
  }
}

module "service-api" {
  source  = "../../../modules/service"
  name    = "${var.name}-api"
  app     = var.name
  release = var.release
  spec = {
    type              = "LoadBalancer"
    loadBalancerIP    = var.api_service_ip
    loadBalancerClass = var.loadbalancer_class_name
    ports = [
      {
        name       = "matchbox-api"
        port       = var.ports.matchbox_api
        protocol   = "TCP"
        targetPort = var.ports.matchbox_api
      },
    ]
  }
}

module "mountpoint" {
  source = "../statefulset_mountpoint"
  ## s3 config
  s3_endpoint          = var.s3_endpoint
  s3_bucket            = var.s3_bucket
  s3_prefix            = ""
  s3_access_key_id     = var.s3_access_key_id
  s3_secret_access_key = var.s3_secret_access_key
  s3_mount_path        = local.data_path
  s3_mount_extra_args  = var.s3_mount_extra_args
  images = {
    mountpoint = var.images.mountpoint
  }
  ##
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.matchbox
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          until mountpoint ${local.data_path}; do
          sleep 1
          done

          exec /matchbox \
            -address=0.0.0.0:${var.ports.matchbox} \
            -rpc-address=0.0.0.0:${var.ports.matchbox_api} \
            -assets-path=${local.data_path} \
            -data-path=${local.data_path} \
            -web-ssl
          EOF
        ]
        # Cert paths are fixed
        volumeMounts = [
          {
            name      = "secret"
            mountPath = "${local.config_path}/ca.crt"
            subPath   = "ca"
          },
          {
            name      = "secret"
            mountPath = "${local.config_path}/server.crt"
            subPath   = "api_cert"
          },
          {
            name      = "secret"
            mountPath = "${local.config_path}/server.key"
            subPath   = "api_key"
          },
          {
            name      = "secret"
            mountPath = "${local.config_path}/ssl/server.crt"
            subPath   = "web_cert"
          },
          {
            name      = "secret"
            mountPath = "${local.config_path}/ssl/server.key"
            subPath   = "web_key"
          },
        ]
        ports = [
          {
            containerPort = var.ports.matchbox
          },
          {
            containerPort = var.ports.matchbox_api
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTPS"
            port   = var.ports.matchbox
            path   = "/"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTPS"
            port   = var.ports.matchbox
            path   = "/"
          }
        }
      },
    ]
    volumes = [
      {
        name = "secret"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}