output "matchbox_rpc_endpoints" {
  value = {
    for host, params in var.kvm_hosts :
    host => {
      endpoint        = "${params.host_network.store.ip}:${var.services.renderer.ports.rpc}"
      cert_pem        = tls_locally_signed_cert.matchbox-client.cert_pem
      private_key_pem = tls_private_key.matchbox-client.private_key_pem
      ca_pem          = tls_self_signed_cert.matchbox-ca.cert_pem
    }
  }
}

output "libvirt_endpoints" {
  value = {
    for host, params in var.kvm_hosts :
    host => {
      endpoint = "qemu+ssh://${var.user}@${params.host_network.store.ip}/system"
    }
  }
}

output "templates" {
  value = {
    for host, params in var.kvm_hosts :
    host => [
      for template in var.kvm_templates :
      templatefile(template, {
        hostname           = host
        user               = var.user
        container_images   = var.container_images
        networks           = var.networks
        host_network       = params.host_network
        mtu                = var.mtu
        networks           = var.networks
        services           = var.services
        image_preload_path = "/etc/container-save"

        vlans = [
          for k, v in var.networks :
          k
          if lookup(v, "id", null) != null
        ]
        internal_networks = {
          int = {
            if = var.networks.int.br_if
            ip = var.services.renderer.vip
          }
        }

        kea_path             = "/var/lib/kea"
        matchbox_tls_path    = "/etc/matchbox/certs"
        matchbox_data_path   = "/etc/matchbox/data"
        matchbox_assets_path = "/etc/matchbox/assets"
        tls_matchbox_ca      = replace(tls_self_signed_cert.matchbox-ca.cert_pem, "\n", "\\n")
        tls_matchbox         = replace(tls_locally_signed_cert.matchbox[host].cert_pem, "\n", "\\n")
        tls_matchbox_key     = replace(tls_private_key.matchbox[host].private_key_pem, "\n", "\\n")
      })
    ]
  }
}