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
          echo -e "$kea_config" > ${local.kea_config_path}/kea-dhcp4.conf
          exec kea-dhcp4 \
            -c ${local.kea_config_path}/kea-dhcp4.conf
          EOF
        ]
        env = [
          {
            name = "kea_config"
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
                    name           = "XClient_iPXE"
                    test           = "substring(option[77].hex,0,4) == 'iPXE'"
                    boot-file-name = "http://${local.listen_ip}:${local.service_ports.matchbox}/boot.ipxe"
                  },
                  {
                    name           = "EFI_x86-64"
                    test           = "option[93].hex == 0x0007"
                    next-server    = local.listen_ip
                    boot-file-name = var.ipxe_boot_path
                  },
                ]
                subnet4 = [
                  {
                    subnet = cidrsubnet(var.host_ip, 0, 0)
                    pools = [
                      {
                        pool = cidrsubnet(var.host_ip, 1, 1)
                      }
                    ]
                    require-client-classes = [
                      "XClient_iPXE",
                      "EFI_x86-64",
                    ]
                  },
                ]
              }
            })
          }
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
        name  = "tftpd"
        image = local.container_images.tftpd
        args = [
          "--address",
          "0.0.0.0:${local.ports.tftpd}",
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