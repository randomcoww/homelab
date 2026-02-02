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

  members = [
    for i, ip in var.service_ips :
    {
      name = "${var.name}-${i}"
      ip   = ip
      role = try(element(["primary", "secondary"], i), "backup")
    }
  ]
}

# Kea peers must know the IP (not DNS name) of all peers
# Create a service for each pod with a known IP
module "service-peer" {
  for_each = {
    for _, member in local.members :
    member.name => member
  }

  source  = "../../../modules/service"
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
    "templates/kea-tls.yaml"     = module.kea-tls.manifest
    }, {
    # service with known IP for each member
    for _, service in module.service-peer :
    "templates/service-${service.name}.yaml" => service.manifest
  })
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {

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
                  trust-anchor        = "${local.kea_base_path}/kea-ca-cert.pem",
                  cert-file           = "${local.kea_base_path}/kea-cert.pem",
                  key-file            = "${local.kea_base_path}/kea-key.pem",
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
          # client-system types:
          # https://www.iana.org/assignments/dhcpv6-parameters/dhcpv6-parameters.xhtml#processor-architecture
          {
            name = "iPXE-UEFI"
            test = "substring(option[user-class].hex,0,4) == 'iPXE'"
            # option-data is added by flex options
          },
          # TODO: support multiple archs
          {
            name = "HTTP-UEFI-amd64"
            test = "option[client-system].hex == 0x0010",
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
            name        = "PXE-UEFI-amd64"
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
  }
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
    "checksum/secret"      = sha256(module.secret.manifest)
    "checksum/kea-tls"     = sha256(module.kea-tls.manifest)
  }
  spec = {
    minReadySeconds = 30
  }
  template_spec = {
    hostNetwork       = true
    dnsPolicy         = "ClusterFirstWithHostNet"
    priorityClassName = "system-cluster-critical"
    resources = {
      requests = {
        memory = "128Mi"
      }
      limits = {
        memory = "128Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.kea
        args = [
          "sh",
          "-c",
          <<-EOF
          set -e

          chmod 750 ${dirname(local.kea_socket_path)}
          cat ${local.kea_base_path}/kea-dhcp4.tpl | envsubst > ${local.kea_base_path}/kea-dhcp4.conf

          stork-agent \
            --listen-prometheus-only \
            --prometheus-kea-exporter-address=0.0.0.0 \
            --prometheus-kea-exporter-port=${var.ports.kea_metrics} \
            --prometheus-kea-exporter-per-subnet-stats=true \
            --prometheus-bind9-exporter-address=127.0.0.1 \
            --prometheus-bind9-exporter-port=0 &

          cd $(dirname $(which kea-dhcp4))
          exec kea-dhcp4 -c ${local.kea_base_path}/kea-dhcp4.conf
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
            name        = "config"
            mountPath   = "${local.kea_base_path}/kea-dhcp4.tpl"
            subPathExpr = "kea-dhcp4-$(POD_NAME).tpl"
          },
          {
            name      = "kea-tls"
            mountPath = "${local.kea_base_path}/kea-ca-cert.pem"
            subPath   = "ca.crt"
          },
          {
            name        = "kea-tls"
            mountPath   = "${local.kea_base_path}/kea-cert.pem"
            subPathExpr = "$(POD_NAME)-tls.crt"
          },
          {
            name        = "kea-tls"
            mountPath   = "${local.kea_base_path}/kea-key.pem"
            subPathExpr = "$(POD_NAME)-tls.key"
          },
          {
            name      = "socket-path"
            mountPath = dirname(local.kea_socket_path)
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
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "kea-tls"
        secret = {
          secretName = module.kea-tls.name
        }
      },
    ]
  }
}