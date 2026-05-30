locals {
  redis_port     = 6379
  base_path      = "/etc/valkey"
  initial_master = "${var.name}-0"
  members = [
    for i, _ in range(var.replicas) :
    {
      name = "${var.name}-${i}"
    }
  ]
  domain_regex          = "(?<hostname>(?<subdomain>[a-z0-9-*]+)\\.(?<domain>[a-z0-9.-]+))(?::(?<port>\\d+))?"
  headless_service      = "${var.name}-svc"
  headless_service_fqdn = "${local.headless_service}.${regex(local.domain_regex, var.service_hostname).domain}"

  valkey_configs = {
    for _, member in local.members :
    "valkey-${member.name}.conf" => <<EOF
port 0
tls-port ${local.redis_port}
bind 0.0.0.0
daemonize no
unixsocket ${local.base_path}/valkey.sock

protected-mode no
dir ${local.base_path}
appendonly yes

tls-auth-clients yes
tls-replication yes
tls-ca-cert-file ${local.base_path}/ca.crt
tls-cert-file ${local.base_path}/valkey.crt
tls-key-file ${local.base_path}/valkey.key

%{if member.name != local.initial_master~}
replicaof ${local.initial_master}.${local.headless_service_fqdn} ${local.redis_port}
%{~endif}
replica-announce-ip ${member.name}.${local.headless_service_fqdn}
min-replicas-to-write 1
min-replicas-max-lag 10
EOF
  }

  sentinel_configs = {
    for _, member in local.members :
    "sentinel-${member.name}.conf" => <<EOF
port 0
tls-port ${var.ports.sentinel}
bind 0.0.0.0
daemonize no
unixsocket ${local.base_path}/sentinel.sock

tls-auth-clients yes
tls-replication yes
tls-ca-cert-file ${local.base_path}/ca.crt
tls-cert-file ${local.base_path}/valkey.crt
tls-key-file ${local.base_path}/valkey.key
tls-client-cert-file ${local.base_path}/valkey.crt
tls-client-key-file ${local.base_path}/valkey.key

sentinel resolve-hostnames yes
sentinel announce-hostnames yes
sentinel announce-ip ${member.name}.${local.headless_service_fqdn}

sentinel monitor ${var.name} ${local.initial_master}.${local.headless_service_fqdn} ${local.redis_port} ${var.replicas - 1}
sentinel down-after-milliseconds ${var.name} 5000
sentinel failover-timeout ${var.name} 60000
sentinel parallel-syncs ${var.name} 1
sentinel myid ${sha1(member.name)}
%{~for _, remote in local.members}%{if remote.name != member.name}
sentinel known-sentinel ${var.name} ${remote.name}.${local.headless_service_fqdn} ${var.ports.sentinel} ${sha1(remote.name)}
%{endif}%{endfor~}
EOF
  }

  manifests = [
    module.configmap.manifest,
    module.tls.manifest,
    module.statefulset.manifest,
    module.service.manifest,
    module.service-headless.manifest,
  ]
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
        name       = "sentinel"
        port       = var.ports.sentinel
        protocol   = "TCP"
        targetPort = var.ports.sentinel
      },
    ]
  }
}

module "service-headless" {
  source  = "../../../modules/service"
  name    = local.headless_service
  app     = var.name
  release = var.release
  spec = {
    type                     = "ClusterIP"
    clusterIP                = "None"
    publishNotReadyAddresses = true
    ports = [
      {
        name       = "redis"
        port       = local.redis_port
        protocol   = "TCP"
        targetPort = local.redis_port
      },
      {
        name       = "sentinel"
        port       = var.ports.sentinel
        protocol   = "TCP"
        targetPort = var.ports.sentinel
      },
    ]
  }
}

module "configmap" {
  source  = "../../../modules/configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data    = merge(local.valkey_configs, local.sentinel_configs)
}

module "statefulset" {
  source   = "../../../modules/statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = {
    "checksum/configmap" = sha256(module.configmap.manifest)
    "checksum/secret"    = sha256(module.tls.manifest)
  }
  spec = {
    minReadySeconds = 30
    serviceName     = module.service-headless.name
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.valkey
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          cp ${local.base_path}/valkey-init.conf \
            ${local.base_path}/valkey.conf
          exec valkey-server ${local.base_path}/valkey.conf
          EOF
        ]
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
        ports = [
          {
            containerPort = local.redis_port
          },
        ]
        volumeMounts = [
          {
            name      = "valkey-data"
            mountPath = local.base_path
          },
          {
            name        = "config"
            mountPath   = "${local.base_path}/valkey-init.conf"
            subPathExpr = "valkey-$(POD_NAME).conf"
          },
          {
            name        = "tls"
            mountPath   = "${local.base_path}/valkey.crt"
            subPathExpr = "$(POD_NAME)-tls.crt"
            readOnly    = true
          },
          {
            name        = "tls"
            mountPath   = "${local.base_path}/valkey.key"
            subPathExpr = "$(POD_NAME)-tls.key"
            readOnly    = true
          },
          {
            name      = "tls"
            mountPath = "${local.base_path}/ca.crt"
            subPath   = "ca.crt"
            readOnly  = true
          },
        ]
        livenessProbe = {
          exec = {
            command = [
              "sh",
              "-c",
              <<-EOF
              set -e

              PING_STATUS=$(valkey-cli -s ${local.base_path}/valkey.sock ping)
              if [[ "$PING_STATUS" == "PONG" ]]; then
                exit 0
              fi
              exit 1
              EOF
            ]
          }
          initialDelaySeconds = 10
        }
        readinessProbe = {
          exec = {
            command = [
              "sh",
              "-c",
              <<-EOF
              set -e

              PING_STATUS=$(valkey-cli -s ${local.base_path}/valkey.sock ping)
              if [[ "$PING_STATUS" == "PONG" ]]; then
                exit 0
              fi
              exit 1
              EOF
            ]
          }
        }
      },
      {
        name  = "${var.name}-sentinel"
        image = var.images.valkey
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          cp ${local.base_path}/sentinel-init.conf \
            ${local.base_path}/sentinel.conf
          exec valkey-server ${local.base_path}/sentinel.conf --sentinel
          EOF
        ]
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
        ports = [
          {
            containerPort = var.ports.sentinel
          },
        ]
        volumeMounts = [
          {
            name      = "sentinel-data"
            mountPath = local.base_path
          },
          {
            name        = "config"
            mountPath   = "${local.base_path}/sentinel-init.conf"
            subPathExpr = "sentinel-$(POD_NAME).conf"
          },
          {
            name        = "tls"
            mountPath   = "${local.base_path}/valkey.crt"
            subPathExpr = "$(POD_NAME)-tls.crt"
            readOnly    = true
          },
          {
            name        = "tls"
            mountPath   = "${local.base_path}/valkey.key"
            subPathExpr = "$(POD_NAME)-tls.key"
            readOnly    = true
          },
          {
            name      = "tls"
            mountPath = "${local.base_path}/ca.crt"
            subPath   = "ca.crt"
            readOnly  = true
          },
        ]
        livenessProbe = {
          exec = {
            command = [
              "sh",
              "-c",
              <<-EOF
              set -e

              PING_STATUS=$(valkey-cli -s ${local.base_path}/sentinel.sock ping)
              if [[ "$PING_STATUS" == "PONG" ]]; then
                exit 0
              fi
              exit 1
              EOF
            ]
          }
          initialDelaySeconds = 10
        }
        readinessProbe = {
          exec = {
            command = [
              "sh",
              "-c",
              <<-EOF
              set -e

              PING_STATUS=$(valkey-cli -s ${local.base_path}/sentinel.sock ping)
              if [[ "$PING_STATUS" == "PONG" ]]; then
                exit 0
              fi
              exit 1
              EOF
            ]
          }
        }
      },
    ]
    volumes = [
      {
        name = "valkey-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "sentinel-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "config"
        configMap = {
          name = module.configmap.name
        }
      },
      {
        name = "tls"
        secret = {
          secretName = module.tls.name
        }
      },
    ]
  }
}