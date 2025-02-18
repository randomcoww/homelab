locals {
  base_path                      = "/etc/kea"
  kea_dhcp4_config_template_path = "${local.base_path}/kea-dhcp4.tpl"
  kea_dhcp4_config_path          = "${local.base_path}/kea-dhcp4.conf"
  kea_ctrl_agent_config_path     = "${local.base_path}/kea-ctrl-agent.conf"
  ha_ca_cert_path                = "${local.base_path}/ca_cert.pem"
  ha_cert_path                   = "${local.base_path}/cert.pem"
  ha_key_path                    = "${local.base_path}/key.pem"
  kea_socket_path                = "/var/tmp/kea/kea-dhcp4-ctrl.sock"

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
      http-host = "127.0.0.1"
      http-port = 8080
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
            library    = "${var.kea_hooks_libraries_path}/libdhcp_lease_cmds.so"
            parameters = {}
          },
          {
            library = "${var.kea_hooks_libraries_path}/libdhcp_stat_cmds.so"
          },
          ], length(var.service_ips) > 1 ? [
          {
            library = "${var.kea_hooks_libraries_path}/libdhcp_ha.so"
            parameters = {
              high-availability = [
                {
                  this-server-name    = member.name
                  trust-anchor        = local.ha_ca_cert_path,
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
            name           = "XClient_iPXE"
            test           = "substring(option[77].hex,0,4) == 'iPXE'"
            boot-file-name = var.ipxe_script_url
          },
          {
            name           = "EFI_x86-64"
            test           = "option[93].hex == 0x0007"
            next-server    = "$POD_IP"
            boot-file-name = var.ipxe_boot_path
          },
          # {
          #   name           = "HTTPClient"
          #   test           = "option[93].hex == 0x0010"
          #   boot-file-name = "https://boot.ipxe.org/ipxe.efi"
          #   option-data = [
          #     {
          #       name = "vendor-class-identifier"
          #       data = "HTTPClient"
          #     },
          #   ]
          # },
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
    basename(local.ha_ca_cert_path)            = tls_self_signed_cert.kea-ca.cert_pem
    basename(local.kea_ctrl_agent_config_path) = jsonencode(local.ctrl_agent_config)
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
      {
        name       = "kea-metrics"
        port       = var.ports.kea_metrics
        protocol   = "TCP"
        targetPort = var.ports.kea_metrics
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
    "checksum/secret" = sha256(module.secret.manifest)
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

          mkdir -p /var/run/kea
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
            mountPath   = local.ha_ca_cert_path
            subPathExpr = basename(local.ha_ca_cert_path)
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
        name : "${var.name}-tftpd"
        image : var.images.tftpd
        args = [
          "--address",
          "0.0.0.0:${var.ports.tftpd}",
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
      {
        name  = "${var.name}-ctrl-agent"
        image = var.images.kea
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mkdir -p /var/run/kea
          exec kea-ctrl-agent -c ${local.kea_ctrl_agent_config_path}
          EOF
        ]
        volumeMounts = [
          {
            name        = "kea-config"
            mountPath   = local.kea_ctrl_agent_config_path
            subPathExpr = basename(local.kea_ctrl_agent_config_path)
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
        ]
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