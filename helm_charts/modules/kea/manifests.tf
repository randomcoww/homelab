locals {
  shared_data_path = "/var/lib/kea"

  peers = [
    for i, ip in var.service_ips :
    {
      name          = "${var.name}-${i}"
      role          = try(element(["primary", "secondary"], i), "backup")
      ip            = ip
      url           = "http://${ip}:${var.ports.kea_peer}/"
      auto-failover = true
    }
  ]

  configs = {
    for i, peer in local.peers :
    peer.name => merge(peer, {
      ctrl_agent_config = {
        Control-agent = {
          http-host = "0.0.0.0"
          http-port = var.ports.kea_peer
          control-sockets = {
            dhcp4 = {
              socket-type = "unix"
              socket-name = "${local.shared_data_path}/kea-dhcp4-ctrl.sock"
            }
          }
        }
      }
      dhcp4_config = {
        Dhcp4 = {
          valid-lifetime = 7200
          renew-timer    = 1800
          rebind-timer   = 3600
          lease-database = {
            type    = "memfile"
            persist = true
            name    = "${local.shared_data_path}/kea-leases4.csv"
          }
          interfaces-config = {
            interfaces = ["*"]
          }
          control-socket = {
            socket-type = "unix"
            socket-name = "${local.shared_data_path}/kea-dhcp4-ctrl.sock"
          }
          hooks-libraries = length(local.peers) > 1 ? [
            {
              library    = "${var.kea_hooks_libraries_path}/libdhcp_lease_cmds.so"
              parameters = {}
            },
            {
              library = "${var.kea_hooks_libraries_path}/libdhcp_ha.so"
              parameters = {
                high-availability = [
                  {
                    this-server-name    = "${peer.name}"
                    mode                = "load-balancing"
                    max-unacked-clients = 0
                    peers               = local.peers
                  },
                ]
              }
            },
          ] : []
          client-classes = [
            {
              name           = "XClient_iPXE"
              test           = "substring(option[77].hex,0,4) == 'iPXE'"
              boot-file-name = var.ipxe_script_url
            },
            {
              name            = "EFI_x86-64"
              test            = "option[93].hex == 0x0007"
              server-hostname = "${peer.name}.${var.name}.${var.namespace}.svc"
              boot-file-name  = var.ipxe_boot_path
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
            for network_name, network in var.networks :
            {
              subnet = network.prefix,
              option-data = [
                {
                  name = "routers"
                  data = join(",", network.routers)
                },
                {
                  name = "domain-name-servers"
                  data = join(",", network.domain_name_servers)
                },
                {
                  name = "interface-mtu"
                  data = format("%s", network.mtu)
                },
                {
                  name = "domain-search"
                  data = join(",", network.domain_search)
                },
              ]
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
    })
  }
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.kea)[1]
  manifests = merge({
    "templates/configmap.yaml"   = module.configmap.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
    }, {
    for k, service in module.service-peer :
    "templates/service-${k}.yaml" => service.manifest
  })
}

module "configmap" {
  source  = "../configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    for i, config in local.configs :
    "kea-dhcp4-${config.name}" => jsonencode(config.dhcp4_config)
    }, {
    for i, config in local.configs :
    "kea-ctrl-agent-${config.name}" => jsonencode(config.ctrl_agent_config)
  })
}

# Create DNS entries that point to host IP (with hostNetwork: true)
# tftp will not work as a service without workarounds and needs direct access to the host
module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type      = "ClusterIP"
    clusterIP = "None"
  }
}

# Kea peers must know the IP (not DNS name) of all peers
# Create a service for each pod with a known IP
module "service-peer" {
  for_each = local.configs

  source  = "../service"
  name    = each.key
  app     = var.name
  release = var.release
  spec = {
    type      = "ClusterIP"
    clusterIP = each.value.ip
    ports = [
      {
        name       = "kea-peer"
        port       = var.ports.kea_peer
        protocol   = "TCP"
        targetPort = var.ports.kea_peer
      }
    ]
    selector = {
      app                                  = var.name
      "statefulset.kubernetes.io/pod-name" = each.key
    }
  }
}

module "statefulset" {
  source            = "../statefulset"
  name              = var.name
  app               = var.name
  release           = var.release
  affinity          = var.affinity
  replicas          = length(local.configs)
  min_ready_seconds = 30
  annotations = {
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  spec = {
    hostNetwork = true
    dnsPolicy   = "ClusterFirstWithHostNet"
    containers = [
      {
        name  = "${var.name}-control-agent"
        image = var.images.kea
        args = [
          "kea-ctrl-agent",
          "-c",
          "/etc/kea/kea-ctrl-agent.conf",
        ]
        env = [
          {
            name = "POD_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.name"
              }
            }
          }
        ]
        volumeMounts = [
          {
            name      = "shared-data"
            mountPath = local.shared_data_path
          },
          {
            name        = "kea-config"
            mountPath   = "/etc/kea/kea-ctrl-agent.conf"
            subPathExpr = "kea-ctrl-agent-$(POD_NAME)"
            readOnly    = true
          },
        ]
      },
      {
        name  = var.name
        image = var.images.kea
        args = [
          "kea-dhcp4",
          "-c",
          "/etc/kea/kea-dhcp4.conf",
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
        securityContext = {
          capabilities = {
            add = [
              "NET_RAW",
            ]
          }
        }
        volumeMounts = [
          {
            name      = "shared-data"
            mountPath = local.shared_data_path
          },
          {
            name        = "kea-config"
            mountPath   = "/etc/kea/kea-dhcp4.conf"
            subPathExpr = "kea-dhcp4-$(POD_NAME)"
            readOnly    = true
          },
        ]
      },
      {
        name : "${var.name}-tftpd"
        image : var.images.tftpd
        args = [
          "--address",
          "0.0.0.0:${var.ports.tftpd}",
          "--verbose",
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
        name = "shared-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "kea-config"
        configMap = {
          name = var.name
        }
      },
    ]
  }
}