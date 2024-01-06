locals {
  listen_ip = split("/", var.host_ip)[0]
  manifests = {
    for f in fileset(".", "${path.module}/manifests/*.yaml") :
    basename(f) => templatefile(f, {
      container_images  = local.container_images
      matchbox_port     = local.ports.matchbox
      matchbox_api_port = local.ports.matchbox_api
      tftp_port         = local.ports.tftpd
      config_path       = "/etc/bootstrap"
      assets_path       = abspath(var.assets_path)
      ca                = chomp(tls_self_signed_cert.matchbox-ca.cert_pem)
      cert              = chomp(tls_locally_signed_cert.matchbox.cert_pem)
      key               = chomp(tls_private_key.matchbox.private_key_pem)
      kea_config = {
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
              boot-file-name = "http://${local.listen_ip}:${local.ports.matchbox}/boot.ipxe"
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
      }
    })
  }
}