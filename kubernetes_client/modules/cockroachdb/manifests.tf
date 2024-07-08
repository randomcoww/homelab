locals {
  name      = split(".", var.cluster_service_endpoint)[0]
  namespace = split(".", var.cluster_service_endpoint)[1]

  certs_path       = "/etc/cockroachdb"
  init_client_user = "root"
  cert_path        = "${local.certs_path}/node.crt"
  key_path         = "${local.certs_path}/node.key"
  ca_cert_path     = "${local.certs_path}/ca.crt"
  client_cert_path = "${local.certs_path}/client.${local.init_client_user}.crt"
  client_key_path  = "${local.certs_path}/client.${local.init_client_user}.key"
  ports = {
    http = 8080
  }
  members = [
    for i in range(var.replicas) :
    "${local.name}-${i}"
  ]

  config = merge(var.extra_configs, {
    certs-dir           = local.certs_path
    advertise-addr      = "$(POD_NAME).${var.cluster_service_endpoint}:${var.ports.cockroachdb}"
    listen-addr         = "$(POD_NAME).${var.cluster_service_endpoint}:${var.ports.cockroachdb}"
    advertise-http-addr = "$(POD_NAME).${var.cluster_service_endpoint}:${local.ports.http}"
    http-addr           = "$(POD_NAME).${var.cluster_service_endpoint}:${local.ports.http}"
    join = join(",", [
      for member in local.members :
      "${member}.${var.cluster_service_endpoint}:${var.ports.cockroachdb}"
    ])
    cluster-name = local.name
    http-port    = local.ports.http
    port         = var.ports.cockroachdb
  })
}

module "metadata" {
  source      = "../metadata"
  name        = local.name
  namespace   = local.namespace
  release     = var.release
  app_version = split(":", var.images.cockroachdb)[1]
  manifests = {
    "templates/service.yaml"      = module.service.manifest
    "templates/service-peer.yaml" = module.service-peer.manifest
    "templates/secret.yaml"       = module.secret.manifest
    "templates/statefulset.yaml"  = module.statefulset.manifest
    "templates/post-job.yaml" = yamlencode({
      apiVersion = "batch/v1"
      kind       = "Job"
      metadata = {
        name = "${local.name}-init"
        labels = {
          app     = local.name
          release = var.release
        }
        annotations = {
          "helm.sh/hook"               = "post-install,post-upgrade"
          "helm.sh/hook-delete-policy" = "hook-succeeded,before-hook-creation"
        }
      }
      spec = {
        template = {
          metadata = {
            labels = {
              app = local.name
            }
          }
          spec = {
            containers = [
              {
                name  = local.name
                image = var.images.cockroachdb
                command = [
                  "sh",
                  "-c",
                  <<-EOF
                  output=$(cockroach init \
                    --certs-dir=${local.certs_path} \
                    --cluster-name=${local.name} \
                    --host=${var.cluster_service_endpoint}:${var.ports.cockroachdb} \
                  2>&1)
                  echo $output

                  if [[ "$output" =~ .*"Cluster successfully initialized".* || "$output" =~ .*"cluster has already been initialized".* ]]; then
                    exit 0;
                  fi
                  exit 1
                  EOF
                ]
                volumeMounts = [
                  {
                    name        = "secret"
                    mountPath   = local.client_cert_path
                    subPathExpr = basename(local.client_cert_path)
                  },
                  {
                    name        = "secret"
                    mountPath   = local.client_key_path
                    subPathExpr = basename(local.client_key_path)
                  },
                  {
                    name        = "secret"
                    mountPath   = local.ca_cert_path
                    subPathExpr = basename(local.ca_cert_path)
                  },
                ]
              },
            ]
            volumes = [
              {
                name = "secret"
                secret = {
                  secretName  = module.secret.name
                  defaultMode = 256
                }
              },
            ]
            dnsConfig = {
              options = [
                {
                  name  = "ndots"
                  value = "2"
                },
              ]
            }
            restartPolicy = "OnFailure"
          }
        }
      }
    })
  }
}

module "secret" {
  source  = "../secret"
  name    = local.name
  app     = local.name
  release = var.release
  data = merge({
    for member in local.members :
    "node_cert-${member}" => chomp(tls_locally_signed_cert.cockroachdb[member].cert_pem)
    }, {
    for member in local.members :
    "node_key-${member}" => chomp(tls_private_key.cockroachdb[member].private_key_pem)
    }, {
    basename(local.ca_cert_path)     = chomp(var.ca.cert_pem)
    basename(local.client_cert_path) = chomp(tls_locally_signed_cert.cockroachdb-client.cert_pem)
    basename(local.client_key_path)  = chomp(tls_private_key.cockroachdb-client.private_key_pem)
  })
}

module "service" {
  source  = "../service"
  name    = local.name
  app     = local.name
  release = var.release
  spec = {
    type = "ClusterIP"
    # allow init to run while pod is not ready
    publishNotReadyAddresses = true
    ports = [
      {
        name       = "grpc"
        port       = local.config.port
        protocol   = "TCP"
        targetPort = local.config.port
      },
      {
        name       = "http"
        port       = local.config.http-port
        protocol   = "TCP"
        targetPort = local.config.http-port
      },
    ]
  }
}

module "service-peer" {
  source  = "../service"
  name    = "${local.name}-peer"
  app     = local.name
  release = var.release
  spec = {
    type                     = "ClusterIP"
    clusterIP                = "None"
    publishNotReadyAddresses = true
  }
}

module "statefulset" {
  source            = "../statefulset"
  name              = local.name
  app               = local.name
  release           = var.release
  replicas          = var.replicas
  affinity          = var.affinity
  min_ready_seconds = 30
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    containers = [
      {
        name  = local.name
        image = var.images.cockroachdb
        command = concat([
          "cockroach",
          "start",
          ], [
          for k, v in local.config :
          "--${k}=${v}"
        ])
        env = [
          {
            name = "POD_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.name"
              }
            }
          },
        ]
        volumeMounts = concat([
          {
            name        = "secret"
            mountPath   = local.cert_path
            subPathExpr = "node_cert-$(POD_NAME)"
          },
          {
            name        = "secret"
            mountPath   = local.key_path
            subPathExpr = "node_key-$(POD_NAME)"
          },
          {
            name        = "secret"
            mountPath   = local.ca_cert_path
            subPathExpr = basename(local.ca_cert_path)
          },
        ], var.extra_volume_mounts)
        ports = [
          {
            containerPort = local.config.http-port
          },
          {
            containerPort = local.config.port
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.config.http-port
            path   = "/health?ready=1"
          }
          initialDelaySeconds = 10
          periodSeconds       = 5
          failureThreshold    = 2
        }
        livenessProbe = {
          tcpSocket = {
            scheme = "HTTP"
            port   = local.config.http-port
            path   = "/health"
          }
          initialDelaySeconds = 30
          periodSeconds       = 5
        }
      },
    ]
    volumes = concat([
      {
        name = "secret"
        secret = {
          secretName  = module.secret.name
          defaultMode = 256
        }
      },
    ], var.extra_volumes)
  }
  volume_claim_templates = var.volume_claim_templates
}