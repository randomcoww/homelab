locals {
  network_prefix = cidrsubnet(var.host_ip, 0, 0)
  listen_ip      = split("/", var.host_ip)[0]
  manifests = {
    for f in fileset(".", "${path.module}/manifests/*.yaml") :
    basename(f) => templatefile(f, {
      container_images = local.container_images
      ports            = local.ports
      config_path      = "/etc/bootstrap"
      assets_path      = abspath(var.assets_path)
      ca               = chomp(tls_self_signed_cert.matchbox-ca.cert_pem)
      cert             = chomp(tls_locally_signed_cert.matchbox.cert_pem)
      key              = chomp(tls_private_key.matchbox.private_key_pem)
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
              subnet = local.network_prefix
              pools = [
                {
                  pool = local.network_prefix
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

# Outputs

output "manifest" {
  value     = join("\n---\n", values(local.manifests))
  sensitive = true
}