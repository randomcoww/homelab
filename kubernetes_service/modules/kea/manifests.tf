locals {
  members = [
    for i, ip in var.service_ips :
    {
      name = "${var.name}-${i}"
      ip   = ip
      role = try(element(["primary", "secondary"], i), "backup")
    }
  ]

  subnet_id_base = 1
  configs = {
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
        hooks-libraries = length(var.service_ips) > 1 ? [
          {
            library    = "${var.kea_hooks_libraries_path}/libdhcp_lease_cmds.so"
            parameters = {}
          },
          {
            library = "${var.kea_hooks_libraries_path}/libdhcp_ha.so"
            parameters = {
              high-availability = [
                {
                  this-server-name    = member.name
                  mode                = "load-balancing"
                  max-unacked-clients = 0
                  peers = [
                    for j, peer in local.members :
                    {
                      name          = peer.name
                      role          = peer.role
                      url           = i == j ? "http://$POD_IP:${var.ports.kea_peer}/" : "http://${peer.ip}:${var.ports.kea_peer}/"
                      auto-failover = true
                    }
                  ]
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
    "templates/configmap.yaml"   = module.configmap.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
    }, {
    for k, service in module.service-peer :
    "templates/service-${k}.yaml" => service.manifest
  })
}

module "configmap" {
  source  = "../../../modules/configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    for host, config in local.configs :
    "kea-dhcp4-${host}" => jsonencode(config)
  }
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
  replicas = length(local.configs)
  annotations = {
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  spec = {
    minReadySeconds = 30
  }
  template_spec = {
    hostNetwork = true
    dnsPolicy   = "ClusterFirstWithHostNet"
    containers = [
      {
        name  = var.name
        image = var.images.kea
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          cat /etc/kea/kea-dhcp4.tpl | envsubst > /etc/kea/kea-dhcp4.conf
          exec kea-dhcp4 -c /etc/kea/kea-dhcp4.conf
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
            mountPath   = "/etc/kea/kea-dhcp4.tpl"
            subPathExpr = "kea-dhcp4-$(POD_NAME)"
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
    ]
    volumes = [
      {
        name = "kea-config"
        configMap = {
          name = module.configmap.name
        }
      },
    ]
  }
}