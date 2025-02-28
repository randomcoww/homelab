locals {
  name      = split(".", var.cluster_service_endpoint)[0]
  namespace = split(".", var.cluster_service_endpoint)[1]
  data_path = "/var/lib/matchbox/mnt"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = local.name
  namespace   = local.namespace
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
  name    = local.name
  app     = local.name
  release = var.release
  data = {
    "ca.crt"     = chomp(var.ca.cert_pem)
    "server.crt" = chomp(tls_locally_signed_cert.matchbox.cert_pem)
    "server.key" = chomp(tls_private_key.matchbox.private_key_pem)
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = local.name
  app     = local.name
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
  name    = "${local.name}-api"
  app     = local.name
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
  name     = local.name
  app      = local.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = local.name
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
            -data-path=${local.data_path}
          EOF
        ]
        volumeMounts = [
          {
            name      = "matchbox-secret"
            mountPath = "/etc/matchbox"
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
            scheme = "HTTP"
            port   = var.ports.matchbox
            path   = "/"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = var.ports.matchbox
            path   = "/"
          }
        }
      },
    ]
    volumes = [
      {
        name = "matchbox-secret"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}