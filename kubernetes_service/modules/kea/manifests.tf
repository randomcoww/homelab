locals {
  base_path                      = "/etc/kea"
  kea_dhcp4_config_template_path = "${local.base_path}/kea-dhcp4.tpl"
  kea_dhcp4_config_path          = "${local.base_path}/kea-dhcp4.conf"
  kea_ctrl_agent_config_path     = "${local.base_path}/kea-ctrl-agent.conf"
  kea_socket_path                = "/var/run/kea/kea-dhcp4-ctrl.sock"
  kea_hooks_libraries_path       = "/usr/lib/kea/hooks"
  ca_cert_path                   = "${local.base_path}/ca-cert.pem"
  ha_cert_path                   = "${local.base_path}/ha-cert.pem"
  ha_key_path                    = "${local.base_path}/ha-key.pem"
  ctrl_agent_cert_path           = "${local.base_path}/agent-cert.pem"
  ctrl_agent_key_path            = "${local.base_path}/agent-key.pem"
  # These paths are hard coded in stork
  stork_agent_cert_path     = "/var/lib/stork-agent/certs/cert.pem"
  stork_agent_key_path      = "/var/lib/stork-agent/certs/key.pem"
  stork_agent_ca_cert_path  = "/var/lib/stork-agent/certs/ca.pem"
  stork_agent_cert_sha_path = "/var/lib/stork-agent/tokens/server-cert.sha256"
  stork_agent_token_path    = "/var/lib/stork-agent/tokens/agent-token.txt"

  members = [
    for i, ip in var.service_ips :
    {
      name = "${var.name}-${i}"
      ip   = ip
      role = try(element(["primary", "secondary"], i), "backup")
    }
  ]
  subnet_id_base = 1
  ctrl_agent_config = {
    Control-agent = {
      http-host     = "127.0.0.1"
      http-port     = var.ports.kea_ctrl_agent
      trust-anchor  = local.ca_cert_path
      cert-file     = local.ctrl_agent_cert_path
      key-file      = local.ctrl_agent_key_path
      cert-required = true
      control-sockets = {
        dhcp4 = {
          socket-type = "unix"
          socket-name = local.kea_socket_path
        }
      }
    }
  }
  dhcp4_config = {
    for i, member in local.members :
    member.name => {
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
          # pass ipxe?mac={mac} host script endpoint directly from kea
          # {
          #   library = "${local.kea_hooks_libraries_path}/libdhcp_flex_option.so"
          #   parameters = {
          #     options = [
          #       {
          #         client-class = "iPXE-UEFI"
          #         name         = "boot-file-name"
          #         supersede    = "'${var.ipxe_script_url}?mac=' + hexstring(pkt4.mac, '-')"
          #       },
          #     ]
          #   }
          # },
          ], length(var.service_ips) > 1 ? [
          {
            library = "${local.kea_hooks_libraries_path}/libdhcp_ha.so"
            parameters = {
              high-availability = [
                {
                  this-server-name    = member.name
                  trust-anchor        = local.ca_cert_path,
                  cert-file           = local.ha_cert_path,
                  key-file            = local.ha_key_path,
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
          {
            name = "iPXE-UEFI"
            test = "substring(option[user-class].hex,0,4) == 'iPXE'"
            option-data = [
              {
                name = "boot-file-name"
                data = var.ipxe_script_url
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
            id     = local.subnet_id_base + k
            option-data = concat([
              {
                name = "interface-mtu"
                data = format("%s", network.mtu)
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
              for _, pool in network.pools :
              {
                pool = pool
              }
            ]
          }
        ]
      }
    }
  }
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.kea)[1]
  manifests = merge({
    "templates/secret.yaml"      = module.secret.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
    }, {
    for k, service in module.service-peer :
    "templates/service-${k}.yaml" => service.manifest
  })
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    for host, config in local.dhcp4_config :
    "kea-dhcp4-${host}" => jsonencode(config)
    }, {
    for host, _ in local.dhcp4_config :
    "ha-cert-${host}" => tls_locally_signed_cert.kea[host].cert_pem
    }, {
    for host, _ in local.dhcp4_config :
    "ha-key-${host}" => tls_private_key.kea[host].private_key_pem
    }, {
    "kea-ctrl-agent"       = jsonencode(local.ctrl_agent_config)
    "ca-cert"              = tls_self_signed_cert.kea-ca.cert_pem
    "ctrl-agent-cert"      = tls_locally_signed_cert.kea-ctrl-agent.cert_pem
    "ctrl-agent-key"       = tls_private_key.kea-ctrl-agent.private_key_pem
    "stork-agent-cert"     = tls_locally_signed_cert.kea-stork-agent.cert_pem
    "stork-agent-key"      = tls_private_key.kea-stork-agent.private_key_pem_pkcs8
    "stork-agent-cert-sha" = sha256(tls_locally_signed_cert.kea-stork-agent.cert_pem)
    "stork-agent-token"    = var.stork_agent_token
  })
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

module "statefulset" {
  source   = "../../../modules/statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = length(local.dhcp4_config)
  annotations = {
    "checksum/secret"      = sha256(module.secret.manifest)
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = tostring(var.ports.kea_metrics)
  }
  spec = {
    minReadySeconds = 30
  }
  template_spec = {
    # stork agent looks for kea-ctrl-agent process
    shareProcessNamespace = true
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
          cat ${local.kea_dhcp4_config_template_path} | envsubst > ${local.kea_dhcp4_config_path}
          exec kea-dhcp4 -c ${local.kea_dhcp4_config_path}
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
            name        = "kea-config"
            mountPath   = local.kea_dhcp4_config_template_path
            subPathExpr = "kea-dhcp4-$(POD_NAME)"
          },
          {
            name        = "kea-config"
            mountPath   = local.ca_cert_path
            subPathExpr = "ca-cert"
          },
          {
            name        = "kea-config"
            mountPath   = local.ha_cert_path
            subPathExpr = "ha-cert-$(POD_NAME)"
          },
          {
            name        = "kea-config"
            mountPath   = local.ha_key_path
            subPathExpr = "ha-key-$(POD_NAME)"
          },
          {
            name      = "socket-path"
            mountPath = dirname(local.kea_socket_path)
          },
        ]
      },
      {
        name  = "${var.name}-ctrl-agent"
        image = var.images.kea
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          chmod 750 ${dirname(local.kea_socket_path)}
          exec kea-ctrl-agent -c ${local.kea_ctrl_agent_config_path}
          EOF
        ]
        volumeMounts = [
          {
            name        = "kea-config"
            mountPath   = local.kea_ctrl_agent_config_path
            subPathExpr = "kea-ctrl-agent"
          },
          {
            name        = "kea-config"
            mountPath   = local.ca_cert_path
            subPathExpr = "ca-cert"
          },
          {
            name        = "kea-config"
            mountPath   = local.ctrl_agent_cert_path
            subPathExpr = "ctrl-agent-cert"
          },
          {
            name        = "kea-config"
            mountPath   = local.ctrl_agent_key_path
            subPathExpr = "ctrl-agent-key"
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
        args = [
          "--listen-prometheus-only",
          "--prometheus-kea-exporter-port=${var.ports.kea_metrics}",
          "--prometheus-bind9-exporter-address=127.0.0.1", # don't want this
        ]
        volumeMounts = [
          {
            name        = "kea-config"
            mountPath   = local.kea_ctrl_agent_config_path
            subPathExpr = basename(local.kea_ctrl_agent_config_path)
          },
          {
            name        = "kea-config"
            mountPath   = local.stork_agent_ca_cert_path
            subPathExpr = "ca-cert"
          },
          {
            name        = "kea-config"
            mountPath   = local.stork_agent_cert_path
            subPathExpr = "stork-agent-cert"
          },
          {
            name        = "kea-config"
            mountPath   = local.stork_agent_key_path
            subPathExpr = "stork-agent-key"
          },
          {
            name        = "kea-config"
            mountPath   = local.stork_agent_cert_sha_path
            subPathExpr = "stork-agent-cert-sha"
          },
          {
            name        = "kea-config"
            mountPath   = local.stork_agent_token_path
            subPathExpr = "stork-agent-token"
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
        image = var.images.ipxe_tftp
        args = [
          "--address",
          "0.0.0.0:${var.ports.ipxe_tftp}",
        ]
        securityContext = {
          capabilities = {
            add = [
              "SYS_CHROOT",
              "SETUID",
              "SETGID",
            ]
          }
        }
      },
    ]
    volumes = [
      {
        name = "kea-config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "socket-path"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}