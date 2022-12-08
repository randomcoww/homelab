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
              name           = "ipxe_detected"
              test           = "substring(option[77].hex,0,4) == 'iPXE'"
              boot-file-name = "http://${local.listen_ip}:${local.ports.matchbox}/boot.ipxe"
            },
            {
              name           = "ipxe"
              test           = "not(substring(option[77].hex,0,4) == 'iPXE') and (option[93].hex == 0x0000)"
              boot-file-name = "/undionly.kpxe"
            },
            {
              name           = "ipxe_efi"
              test           = "not(substring(option[77].hex,0,4) == 'iPXE') and (option[93].hex == 0x0007)"
              boot-file-name = "/ipxe.efi"
            },
          ]
          subnet4 = [
            {
              subnet      = local.network_prefix
              next-server = local.listen_ip
              pools = [
                {
                  pool = local.network_prefix
                }
              ]
              require-client-classes = [
                "ipxe_detected",
                "ipxe",
                "ipxe_efi",
              ]
            },
          ]
        }
      }
    })
  }
}

resource "local_file" "bootstrap_manifests" {
  for_each = local.manifests

  filename = "${var.manifests_path}/${each.key}"
  content  = each.value
}