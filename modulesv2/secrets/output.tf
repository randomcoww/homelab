locals {
  secrets = yamldecode(data.aws_s3_bucket_object.secrets.body)
}

output "templates" {
  value = merge({
    for host, params in var.wireguard_client_hosts :
    host => [
      for template in var.wireguard_client_templates :
      templatefile(template, {
        wireguard_secret = local.secrets.wireguard
        wireguard_if     = "wg0"
      })
    ]
    },
    {
      for host, params in var.internal_tls_hosts :
      host => [
        for template in var.internal_tls_templates :
        templatefile(template, {
          tls_internal_ca   = replace(tls_self_signed_cert.internal-ca.cert_pem, "\n", "\\n")
          internal_tls_path = "/etc/pki/ca-trust/source/anchors"
        })
      ]
  })
}

output "addons" {
  value = merge(
    {
      wireguard-client-secret = templatefile(var.addon_templates.secret, {
        namespace = "default"
        name      = "wireguard-client"
        type      = "Opaque"
        data = {
          wireguard-client = <<EOF
  [Interface]
  PrivateKey = ${local.secrets.wireguard.Interface.PrivateKey}
  Address = ${local.secrets.wireguard.Interface.Address}
  DNS = ${local.secrets.wireguard.Interface.DNS}
  PostUp = nft add table ip filter && nft add chain ip filter output { type filter hook output priority 0 \; } && nft insert rule ip filter output oifname != "%i" mark != $(wg show %i fwmark) fib daddr type != local ip daddr != ${var.networks.kubernetes.network}/${var.networks.kubernetes.cidr} reject

  [Peer]
  PublicKey = ${local.secrets.wireguard.Peer.PublicKey}
  AllowedIPs = ${local.secrets.wireguard.Peer.AllowedIPs}
  Endpoint = ${local.secrets.wireguard.Peer.Endpoint}
  PersistentKeepalive = 25
  EOF
        }
      }),
      internal-tls-secret = templatefile(var.addon_templates.secret, {
        namespace = "default"
        name      = "internal-tls"
        type      = "kubernetes.io/tls"
        data = {
          "tls.crt" = tls_locally_signed_cert.internal.cert_pem
          "tls.key" = tls_private_key.internal.private_key_pem
        }
      })
    },
    {
      for k, v in var.secrets :
      k => templatefile(var.addon_templates.secret, {
        name      = k
        namespace = v.namespace
        data      = v.data
        type      = v.type
      })
    }
  )
}