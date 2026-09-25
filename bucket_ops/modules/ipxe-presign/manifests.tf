locals {
  config_path  = "/etc/ipxe-presign/config.yaml"
  tls_path     = "/etc/ipxe-presign/tls"
  healthz_port = 8081
}

module "configmap" {
  source    = "../../../modules/configmap"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    basename(local.config_path) = yamlencode(merge(var.extra_configs, {
      listen        = "0.0.0.0:${var.service_port}"
      listenHealthz = "0.0.0.0:${local.healthz_port}"
      advertiseURL  = "https://${var.service_ip}:${var.service_port}"
      serverCert    = "${local.tls_path}/tls.crt"
      serverKey     = "${local.tls_path}/tls.key"
      trustedCAs    = ["${local.tls_path}/ca.crt"]
    }))
  }
}

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  annotations = {
    "lbipam.cilium.io/ips" = var.service_ip
  }
  spec = {
    type = "LoadBalancer"
    ports = [
      {
        name       = "https"
        port       = var.service_port
        protocol   = "TCP"
        targetPort = var.service_port
      },
    ]
  }
}

module "deployment" {
  source = "../../../modules/deployment"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = {
    "checksum/secret"    = sha256(module.minio-user-secret.manifest)
    "checksum/configmap" = sha256(module.configmap.manifest)
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
        image = "${var.images.ipxe-presign.repository}:${var.images.ipxe-presign.tag}"
        args = [
          "-config", local.config_path,
        ]
        env = [
          {
            name = "AWS_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = module.minio-user-secret.name
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "AWS_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = module.minio-user-secret.name
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
          {
            name  = "SSL_CERT_FILE"
            value = "/etc/ssl/certs/ca-certificates.crt"
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
            subPath   = basename(local.config_path)
          },
          {
            name      = "tls"
            mountPath = local.tls_path
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        ports = [
          {
            containerPort = var.service_port
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.healthz_port
            path   = "/healthz"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.healthz_port
            path   = "/healthz"
          }
        }
      },
    ]
    volumes = [
      {
        name = "config"
        configMap = {
          name = module.configmap.name
        }
      },
      {
        name = "ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
      {
        name = "tls"
        csi = {
          driver   = "csi.cert-manager.io"
          readOnly = true
          volumeAttributes = {
            "csi.cert-manager.io/issuer-name" = var.ca_issuer_name
            "csi.cert-manager.io/issuer-kind" = "ClusterIssuer"
            "csi.cert-manager.io/dns-names" = join(",", [
              var.name,
              "${var.name}.${var.namespace}",
            ])
            "csi.cert-manager.io/ip-sans" = join(",", [
              "127.0.0.1",
              var.service_ip,
            ])
            "csi.cert-manager.io/key-algorithm" = "RSA" # compatibility with iPXE
            "csi.cert-manager.io/key-size"      = "4096"
            "csi.cert-manager.io/key-usages" = join(",", [
              "digital signature",
              "key encipherment",
              "server auth",
            ])
          }
        }
      },
    ]
  }
}

module "minio-user-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-minio-user-secret"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    AWS_ACCESS_KEY_ID     = var.minio_user.id
    AWS_SECRET_ACCESS_KEY = var.minio_user.secret
  })
}