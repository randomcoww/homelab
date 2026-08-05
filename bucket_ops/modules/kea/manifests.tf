locals {
  kea_base_path            = "/etc/kea"
  prefix_path              = "/usr/local"
  kea_socket_path          = "${local.prefix_path}/var/run/kea/kea-dhcp4-ctrl.sock"
  kea_hooks_libraries_path = "${local.prefix_path}/lib/kea/hooks" # path in image
  # These paths are not configurable
  # /var/lib/stork-agent/certs/cert.pem
  # /var/lib/stork-agent/certs/key.pem
  # /var/lib/stork-agent/certs/ca.pem
  # /var/lib/stork-agent/tokens/server-cert.sha256
  # /var/lib/stork-agent/tokens/agent-token.txt

  members = [
    for i, ip in var.peer_service_ips :
    {
      name = "${var.name}-${i}"
      ip   = ip
      # role = try(element(["primary", "secondary"], i), "backup") # load-balancing
      role = try(element(["primary", "standby"], i), "backup") # hot-standby
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

  source    = "../../../modules/service"
  name      = each.key
  namespace = var.namespace
  app       = var.name
  release   = var.release
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

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {

    # config for each kea kea-dhcp4-${POD_NAME}.tpl
    for i, member in local.members :
    "kea-dhcp4-${member.name}.tpl" => jsonencode({
      Dhcp4 = {
        valid-lifetime = 3600
        lease-database = {
          type    = "memfile"
          persist = true
        }
        interfaces-config = {
          interfaces = [
            for _, network in var.dhcp_networks :
            network.config.interface
          ]
        }
        control-socket = {
          socket-type = "unix"
          socket-name = local.kea_socket_path
        }
        hooks-libraries = concat([
          {
            library = "${local.kea_hooks_libraries_path}/libdhcp_lease_cmds.so"
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
          ], length(local.members) > 1 ? [
          {
            library = "${local.kea_hooks_libraries_path}/libdhcp_ha.so"
            parameters = {
              high-availability = [
                {
                  this-server-name   = member.name
                  trust-anchor       = "${local.kea_base_path}/kea-ca.crt",
                  cert-file          = "${local.kea_base_path}/kea.crt",
                  key-file           = "${local.kea_base_path}/kea.key",
                  mode               = "hot-standby"
                  heartbeat-delay    = 5000
                  max-response-delay = 30000
                  max-ack-delay      = 3000
                  # Failover immediately so that rolling network reboot works while Kea instances get taken down #
                  max-rejected-lease-updates = 1
                  delayed-updates-limit      = 0
                  max-unacked-clients        = 0
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
          for i, network in var.dhcp_networks :
          {
            subnet = network.config.prefix
            id     = i + 1
            option-data = [
              for name, data in merge(contains(keys(network.config.vips), "vrrp") ? {
                routers = network.config.vips.vrrp
                } : {}, contains(keys(network.config), "mtu") ? {
                interface-mtu = tostring(network.config.mtu)
              } : {}, network.option_data) :
              {
                name = name
                data = data
              }
            ]
            pools = [
              {
                pool = "${cidrhost(cidrsubnet(network.config.prefix, 1, 1), 0)} - ${cidrhost(network.config.prefix, -2)}"
              },
            ]
          }
        ]
      }
    })
  }
}

module "statefulset" {
  source    = "../../../modules/statefulset"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = length(local.members)
  annotations = {
    "checksum/secret"                     = sha256(module.secret.manifest)
    "secret.reloader.stakater.com/reload" = "${var.name}-tls"
  }
  spec = {
    minReadySeconds = 60
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
        image = "${var.images.kea.repository}:${var.images.kea.tag}"
        # bind9-exporter is not used but can't be turned off
        args = [
          "sh",
          "-c",
          <<-EOF
          set -e

          chmod 750 ${dirname(local.kea_socket_path)}
          cat ${local.kea_base_path}/kea-dhcp4.tpl | envsubst > ${local.kea_base_path}/kea-dhcp4.conf

          stork-agent \
            --listen-prometheus-only \
            --prometheus-kea-exporter-address=$(POD_IP) \
            --prometheus-kea-exporter-port=${var.ports.stork} \
            --prometheus-kea-exporter-per-subnet-stats=true \
            --prometheus-bind9-exporter-address=127.0.0.1 &

          cd $(dirname $(which kea-dhcp4))
          exec kea-dhcp4 -d -c ${local.kea_base_path}/kea-dhcp4.conf
          EOF
        ]
        ports = [
          {
            containerPort = var.ports.stork
          },
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
            name      = "tls"
            mountPath = "${local.kea_base_path}/kea.crt"
            subPath   = "tls.crt"
          },
          {
            name      = "tls"
            mountPath = "${local.kea_base_path}/kea.key"
            subPath   = "tls.key"
          },
          {
            name      = "tls"
            mountPath = "${local.kea_base_path}/kea-ca.crt"
            subPath   = "ca.crt"
          },
          {
            name      = "socket-path"
            mountPath = dirname(local.kea_socket_path)
          },
        ]
      },
      {
        name  = "${var.name}-ipxe"
        image = "${var.images.ipxe.repository}:${var.images.ipxe.tag}"
        args = [
          "-p",
          "$(POD_IP):${var.ports.ipxe}",
        ]
        env = [
          {
            name = "POD_IP"
            valueFrom = {
              fieldRef = {
                fieldPath = "status.podIP"
              }
            }
          },
        ]
      },
      # TODO: migrate fully to HTTP boot and remove TFTP
      {
        name  = "${var.name}-ipxe-tftp"
        image = "${var.images.ipxe.repository}:${var.images.ipxe.tag}"
        command = [
          "udpsvd",
          "-vE",
          "$(POD_IP)",
          tostring(var.ports.ipxe_tftp),
          "tftpd",
          "-r",
          "-u",
          "www-data",
          "/var/www",
        ]
        env = [
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
        name = "tls"
        secret = {
          secretName = "${var.name}-tls"
        }
      },
    ]
  }
}