locals {
  kea_base_path            = "/etc/kea"
  kea_socket_path          = "/var/run/kea/kea-dhcp4-ctrl.sock"
  kea_hooks_libraries_path = "/usr/lib/kea/hooks" # path in image

  # These paths are not configurable
  # /var/lib/stork-agent/certs/cert.pem
  # /var/lib/stork-agent/certs/key.pem
  # /var/lib/stork-agent/certs/ca.pem
  # /var/lib/stork-agent/tokens/server-cert.sha256
  # /var/lib/stork-agent/tokens/agent-token.txt
  stork_agent_base_path = "/var/lib/stork-agent"

  kea_ctrl_agent_tls_secret_name = "${var.name}-kea-ctrl-agent-tls"
  stork_agent_tls_secret_name    = "${var.name}-stork-agent-tls"
  members = [
    for i, ip in var.service_ips :
    {
      name                = "${var.name}-${i}"
      ip                  = ip
      role                = try(element(["primary", "secondary"], i), "backup")
      kea_tls_secret_name = "${var.name}-${i}-kea-tls"
    }
  ]
}

resource "random_password" "stork-agent-token" {
  length  = 32
  special = false
}

# Kea peers must know the IP (not DNS name) of all peers
# Create a service for each pod with a known IP
module "service-peer" {
  for_each = {
    for _, member in local.members :
    member.name => member.ip
  }

  source  = "../../../modules/service"
  name    = each.key
  app     = var.name
  release = var.release
  spec = {
    type      = "ClusterIP"
    clusterIP = each.value
    ports = [
      {
        name       = "kea-peer"
        port       = var.ports.kea_peer
        protocol   = "TCP"
        targetPort = var.ports.kea_peer
      },
    ]
    selector = {
      app                                  = var.name
      "statefulset.kubernetes.io/pod-name" = each.key
    }
  }
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = merge({
    "templates/secret.yaml"      = module.secret.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest

    # shared cert for ctrl-agent
    "templates/kea-ctrl-agent-cert.yaml" = yamlencode({
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = local.kea_ctrl_agent_tls_secret_name
        namespace = var.namespace
      }
      spec = {
        secretName = local.kea_ctrl_agent_tls_secret_name
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
        ]
        issuerRef = {
          name = var.ca_issuer_name
          kind = "ClusterIssuer"
        }
      }
    })

    # shared cert for stork agent client
    "templates/stork-agent-cert.yaml" = yamlencode({
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = local.stork_agent_tls_secret_name
        namespace = var.namespace
      }
      spec = {
        secretName = local.stork_agent_tls_secret_name
        isCA       = false
        privateKey = {
          algorithm = "ECDSA"
          encoding  = "PKCS8"
          size      = 521
        }
        commonName = var.name
        usages = [
          "key encipherment",
          "digital signature",
          "client auth",
        ]
        issuerRef = {
          name = var.ca_issuer_name
          kind = "ClusterIssuer"
        }
      }
    })
    }, {

    # cert for each kea member
    for _, member in local.members :
    "templates/cert-${member.name}.yaml" => yamlencode({
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = member.kea_tls_secret_name
        namespace = var.namespace
      }
      spec = {
        secretName = member.kea_tls_secret_name
        isCA       = false
        privateKey = {
          algorithm = "ECDSA"
          size      = 521
        }
        commonName = member.name
        usages = [
          "key encipherment",
          "digital signature",
          "client auth",
          "server auth",
        ]
        issuerRef = {
          name = var.ca_issuer_name
          kind = "ClusterIssuer"
        }
      }
    })
    }, {

    # service with known IP for each member
    for _, service in module.service-peer :
    "templates/service-${service.name}.yaml" => service.manifest
    }
  )
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({

    # config for each kea kea-dhcp4-${POD_NAME}.tpl
    for i, member in local.members :
    "kea-dhcp4-${member.name}.tpl" => jsonencode({
      Dhcp4 = {
        valid-lifetime = 7200
        renew-timer    = 1800
        rebind-timer   = 3600
        lease-database = {
          type    = "memfile"
          persist = true
        }
        interfaces-config = {
          interfaces = ["*"]
        }
        control-socket = {
          socket-type = "unix"
          socket-name = local.kea_socket_path
        }
        hooks-libraries = concat([
          {
            library    = "${local.kea_hooks_libraries_path}/libdhcp_lease_cmds.so"
            parameters = {}
          },
          {
            library = "${local.kea_hooks_libraries_path}/libdhcp_stat_cmds.so"
          },
          {
            library = "${local.kea_hooks_libraries_path}/libdhcp_subnet_cmds.so"
          },
          {
            library = "${local.kea_hooks_libraries_path}/libdhcp_flex_option.so"
            parameters = {
              options = [
                {
                  client-class = "iPXE-UEFI"
                  name         = "boot-file-name"
                  supersede    = "'${var.ipxe_script_base_url}' + hexstring(pkt4.mac, '-')"
                },
              ]
            }
          },
          ], length(var.service_ips) > 1 ? [
          {
            library = "${local.kea_hooks_libraries_path}/libdhcp_ha.so"
            parameters = {
              high-availability = [
                {
                  this-server-name    = member.name
                  trust-anchor        = "${local.kea_base_path}/ca-cert.pem",
                  cert-file           = "${local.kea_base_path}/kea-cert-${member.name}.pem",
                  key-file            = "${local.kea_base_path}/kea-key-${member.name}.pem",
                  mode                = "load-balancing"
                  max-unacked-clients = 0
                  peers = [
                    for j, peer in local.members :
                    {
                      name          = peer.name
                      role          = peer.role
                      url           = i == j ? "https://$POD_IP:${var.ports.kea_peer}/" : "https://${peer.ip}:${var.ports.kea_peer}/"
                      auto-failover = true
                    }
                  ]
                },
              ]
            }
          },
        ] : [])
        client-classes = [
          # TODO: support multiple archs
          {
            name = "iPXE-UEFI"
            test = "substring(option[user-class].hex,0,4) == 'iPXE'"
            option-data = [
              {
                name = "boot-file-name"
                data = var.ipxe_script_base_url # non working URL - assume supersede from libdhcp_flex_option.so
              },
            ]
          },
          {
            name = "HTTP"
            test = "substring(option[vendor-class-identifier].hex,0,10) == 'HTTPClient'",
            option-data = [
              {
                name = "boot-file-name"
                data = "http://$POD_IP:${var.ports.ipxe}/${var.ipxe_boot_file_name}"
              },
              {
                name = "vendor-class-identifier"
                data = "HTTPClient"
              },
            ]
          },
          # TODO: migrate fully to HTTP boot and remove TFTP
          {
            name        = "PXE-UEFI"
            test        = "option[client-system].hex == 0x0007",
            next-server = "$POD_IP"
            option-data = [
              {
                name = "boot-file-name"
                data = var.ipxe_boot_file_name
              },
            ]
          },
        ]
        subnet4 = [
          for k, network in var.networks :
          {
            subnet = network.prefix
            id     = k + 1
            option-data = concat([
              {
                name = "interface-mtu"
                data = tostring(network.mtu)
              },
              {
                name = "tcode"
                data = var.timezone
              },
              ], length(network.routers) > 0 ? [
              {
                name = "routers"
                data = join(",", network.routers)
              }
              ] : [], length(network.domain_name_servers) > 0 ? [
              {
                name = "domain-name-servers"
                data = join(",", network.domain_name_servers)
              }
              ] : [], length(network.domain_search) > 0 ? [
              {
                name = "domain-search"
                data = join(",", network.domain_search)
              }
            ] : [])
            pools = [
              {
                pool = "${cidrhost(cidrsubnet(network.prefix, 1, 1), 0)} - ${cidrhost(network.prefix, -2)}"
              },
            ]
          }
        ]
      }
    })
    }, {

    # shared config for ctrl-agent
    "kea-ctrl-agent.conf" = jsonencode({
      Control-agent = {
        http-host     = "127.0.0.1"
        http-port     = var.ports.kea_ctrl_agent
        trust-anchor  = "${local.kea_base_path}/ca-cert.pem",
        cert-file     = "${local.kea_base_path}/kea-ctrl-agent-cert.pem",
        key-file      = "${local.kea_base_path}/kea-ctrl-agent-key.pem",
        cert-required = true
        control-sockets = {
          dhcp4 = {
            socket-type = "unix"
            socket-name = local.kea_socket_path
          }
        }
      }
    })

    "agent-token.txt" = random_password.stork-agent-token.result # unused but needs to exist
  })
}

module "statefulset" {
  source   = "../../../modules/statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = length(local.members)
  annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = tostring(var.ports.kea_metrics)
  }
  spec = {
    minReadySeconds = 30
  }
  template_spec = {
    shareProcessNamespace = true # stork agent looks for kea-ctrl-agent process
    hostNetwork           = true
    dnsPolicy             = "ClusterFirstWithHostNet"
    containers = [
      {
        name  = var.name
        image = var.images.kea
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          chmod 750 ${dirname(local.kea_socket_path)}
          cat ${local.kea_base_path}/kea-dhcp4-$(POD_NAME).tpl | envsubst > /var/run/kea-dhcp4.conf
          exec kea-dhcp4 -c /var/run/kea-dhcp4.conf
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
          {
            name = "POD_IP"
            valueFrom = {
              fieldRef = {
                fieldPath = "status.podIP"
              }
            }
          },
        ]
        securityContext = {
          capabilities = {
            add = [
              "NET_RAW",
            ]
          }
        }
        volumeMounts = [
          {
            name      = "kea-config"
            mountPath = local.kea_base_path
          },
          {
            name      = "socket-path"
            mountPath = dirname(local.kea_socket_path)
          },
        ]
      },
      {
        name  = "${var.name}-kea-ctrl-agent"
        image = var.images.kea
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          chmod 750 ${dirname(local.kea_socket_path)}
          exec kea-ctrl-agent -c ${local.kea_base_path}/kea-ctrl-agent.conf
          EOF
        ]
        volumeMounts = [
          {
            name      = "kea-config"
            mountPath = local.kea_base_path
          },
          {
            name      = "socket-path"
            mountPath = dirname(local.kea_socket_path)
          },
        ]
      },
      {
        name  = "${var.name}-stork-agent"
        image = var.images.stork_agent
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          sum=$(sha256sum ${local.stork_agent_base_path}/certs/cert.pem | awk '{print $1}')

          mkdir -p ${local.stork_agent_base_path}/tokens
          echo -e "$sum" > ${local.stork_agent_base_path}/tokens/server-cert.sha256

          exec stork-agent \
          --listen-prometheus-only \
          --prometheus-kea-exporter-port=${var.ports.kea_metrics}
          EOF
        ]
        volumeMounts = [
          {
            name      = "kea-config"
            mountPath = local.kea_base_path
          },
          {
            name      = "stork-agent-certs"
            mountPath = "${local.stork_agent_base_path}/certs"
          },
          # This keeps the token path writable to produce tokens/server-cert.sha256
          {
            name      = "stork-agent-token"
            mountPath = "${local.stork_agent_base_path}/tokens/agent-token.txt"
            subPath   = "agent-token.txt"
          },
        ]
      },
      {
        name  = "${var.name}-ipxe"
        image = var.images.ipxe
        args = [
          "-p",
          "0.0.0.0:${var.ports.ipxe}",
        ]
      },
      # TODO: migrate fully to HTTP boot and remove TFTP
      {
        name  = "${var.name}-ipxe-tftp"
        image = var.images.ipxe
        command = [
          "udpsvd",
          "-vE",
          "0.0.0.0",
          tostring(var.ports.ipxe_tftp),
          "tftpd",
          "-r",
          "-u",
          "www-data",
          "/var/www",
        ]
        securityContext = {
          runAsUser = 0 # needed to bind to port 69
          capabilities = {
            add = [
              "SYS_CHROOT",
            ]
          }
        }
      },
    ]
    volumes = [
      {
        name = "socket-path"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "kea-config"
        projected = {
          sources = concat([
            for _, member in local.members :
            {
              secret = {
                name = member.kea_tls_secret_name
                items = [
                  {
                    key  = "tls.crt"
                    path = "kea-cert-${member.name}.pem"
                  },
                  {
                    key  = "tls.key"
                    path = "kea-key-${member.name}.pem"
                  },
                ]
              }
            }
            ], [
            {
              secret = {
                name = module.secret.name
                items = concat([
                  for _, member in local.members :
                  {
                    key  = "kea-dhcp4-${member.name}.tpl"
                    path = "kea-dhcp4-${member.name}.tpl"
                  }
                  ], [
                  {
                    key  = "kea-ctrl-agent.conf"
                    path = "kea-ctrl-agent.conf"
                  },
                ])
              }
            },
            {
              secret = {
                name = local.kea_ctrl_agent_tls_secret_name
                items = [
                  {
                    key  = "ca.crt"
                    path = "ca-cert.pem"
                  },
                  {
                    key  = "tls.crt"
                    path = "kea-ctrl-agent-cert.pem"
                  },
                  {
                    key  = "tls.key"
                    path = "kea-ctrl-agent-key.pem"
                  },
                ]
              }
            },
          ])
        }
      },
      {
        name = "stork-agent-certs"
        projected = {
          sources = [
            {
              secret = {
                name = local.stork_agent_tls_secret_name
                items = [
                  {
                    key  = "ca.crt"
                    path = "ca.pem"
                  },
                  {
                    key  = "tls.crt"
                    path = "cert.pem"
                  },
                  {
                    key  = "tls.key"
                    path = "key.pem"
                  },
                ]
              }
            },
          ]
        }
      },
      {
        name = "stork-agent-token"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}