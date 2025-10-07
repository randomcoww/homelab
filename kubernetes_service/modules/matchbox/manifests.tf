locals {
  data_path       = "/var/lib/matchbox/mnt"
  config_path     = "/etc/matchbox"
  tls_secret_name = "${var.name}-tls"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = merge(module.mountpoint.chart.manifests, {
    "templates/service.yaml"     = module.service.manifest
    "templates/service-api.yaml" = module.service-api.manifest
    "templates/cert.yaml" = yamlencode({
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = var.name
        namespace = var.namespace
      }
      spec = {
        secretName = local.tls_secret_name
        isCA       = false
        privateKey = {
          algorithm = "ECDSA"
          size      = 521
        }
        commonName = var.name
        usages = [
          "key encipherment",
          "digital signature",
          "server auth",
        ]
        ipAddresses = [
          "127.0.0.1",
          var.service_ip,
          var.api_service_ip,
        ]
        dnsNames = [
          var.name,
          "${var.name}.${var.namespace}",
        ]
        issuerRef = {
          name = var.ca_issuer_name
          kind = "ClusterIssuer"
        }
      }
    })
  })
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

module "mountpoint" {
  source = "../statefulset_mountpoint"
  ## s3 config
  s3_endpoint         = var.minio_endpoint
  s3_bucket           = var.minio_bucket
  s3_prefix           = ""
  s3_mount_path       = local.data_path
  s3_mount_extra_args = var.minio_mount_extra_args
  s3_access_secret    = var.minio_access_secret
  images = {
    mountpoint = var.images.mountpoint
  }
  ##
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
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
            name      = "config"
            mountPath = local.config_path
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
        name = "config"
        projected = {
          sources = [
            {
              secret = {
                name = local.tls_secret_name
                items = [
                  {
                    key  = "ca.crt"
                    path = "ca.crt"
                  },
                  {
                    key  = "tls.crt"
                    path = "server.crt"
                  },
                  {
                    key  = "tls.key"
                    path = "server.key"
                  },
                  {
                    key  = "tls.crt"
                    path = "ssl/server.crt"
                  },
                  {
                    key  = "tls.key"
                    path = "ssl/server.key"
                  },
                ]
              }
            },
          ]
        }
      },
    ]
  }
}