locals {
  kea_config_path      = "/etc/kea"
  matchbox_assets_path = "/var/lib/matchbox/assets"
  listen_ip            = split("/", var.host_ip)[0]
}

module "bootstrap" {
  source = "../modules/static_pod"
  name   = "bootstrap"
  spec = {
    containers = [
      {
        name  = "kea"
        image = local.container_images.kea
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          mkdir -p ${local.kea_config_path}
          echo -e "$config" > ${local.kea_config_path}/kea-dhcp4.conf
          exec kea-dhcp4 \
            -c ${local.kea_config_path}/kea-dhcp4.conf
          EOF
        ]
        env = [
          {
            name = "config"
            value = jsonencode({
              Dhcp4 = {
                valid-lifetime = 300
                renew-timer    = 300
                rebind-timer   = 360
                interfaces-config = {
                  interfaces = ["*"]
                }
                client-classes = [
                  {
                    name = "iPXE-UEFI"
                    test = "substring(option[user-class].hex,0,4) == 'iPXE'"
                    option-data = [
                      {
                        name = "boot-file-name"
                        data = "http://${local.listen_ip}:${local.service_ports.matchbox}/boot.ipxe"
                      },
                    ]
                  },
                  {
                    name = "HTTP"
                    test = "substring(option[vendor-class-identifier].hex,0,10) == 'HTTPClient'",
                    option-data = [
                      {
                        name = "boot-file-name"
                        data = "http://${local.listen_ip}:${local.host_ports.ipxe}/${var.ipxe_boot_file_name}"
                      },
                      {
                        name = "vendor-class-identifier"
                        data = "HTTPClient"
                      },
                    ]
                  },
                  {
                    name        = "PXE-UEFI"
                    test        = "option[client-system].hex == 0x0007",
                    next-server = local.listen_ip
                    option-data = [
                      {
                        name = "boot-file-name"
                        data = var.ipxe_boot_file_name
                      },
                    ]
                  },
                ]
                subnet4 = [
                  {
                    subnet = cidrsubnet(var.host_ip, 0, 0)
                    id     = 1
                    pools = [
                      {
                        pool = cidrsubnet(var.host_ip, 1, 1)
                      },
                    ]
                    require-client-classes = [
                      "iPXE-UEFI",
                      "HTTP",
                      "PXE-UEFI",
                    ]
                  },
                ]
              }
            })
          },
        ]
        securityContext = {
          capabilities = {
            add = [
              "NET_RAW",
            ]
          }
        }
      },
      {
        name  = "matchbox"
        image = local.container_images.matchbox
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          mkdir -p /etc/matchbox
          echo -e "$ca" > /etc/matchbox/ca.crt
          echo -e "$cert" > /etc/matchbox/server.crt
          echo -e "$key" > /etc/matchbox/server.key
          exec /matchbox \
            -address=0.0.0.0:${local.service_ports.matchbox} \
            -rpc-address=127.0.0.1:${local.service_ports.matchbox_api} \
            -assets-path=${local.matchbox_assets_path}
          EOF
        ]
        env = [
          {
            name  = "ca"
            value = tls_self_signed_cert.matchbox-ca.cert_pem
          },
          {
            name  = "cert"
            value = tls_locally_signed_cert.matchbox.cert_pem
          },
          {
            name  = "key"
            value = tls_private_key.matchbox.private_key_pem
          },
        ]
        volumeMounts = [
          {
            name      = "assets"
            mountPath = local.matchbox_assets_path
          },
        ]
      },
      {
        name  = "ipxe-http"
        image = local.container_images.ipxe
        args = [
          "-p",
          "0.0.0.0:${local.host_ports.ipxe}",
        ]
      },
      {
        name  = "ipxe-tftp"
        image = local.container_images.ipxe_tftp
        args = [
          "--address",
          "0.0.0.0:${local.host_ports.ipxe_tftp}",
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
        name = "assets"
        hostPath = {
          path = var.assets_path
        }
      },
    ]
  }
}