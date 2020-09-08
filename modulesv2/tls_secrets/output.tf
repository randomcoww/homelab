output "templates" {
  value = {
    for host, params in var.hosts :
    host => [
      for template in var.templates :
      templatefile(template, {
        tls_internal_ca   = replace(tls_self_signed_cert.internal-ca.cert_pem, "\n", "\\n")
        internal_tls_path = "/etc/pki/ca-trust/source/anchors/${var.name}.pem"
      })
    ]
  }
}

output "addons" {
  value = {
    for k, v in var.secrets :
    "${v.namespace}-${v.name}" => templatefile(var.addon_templates.secret, {
      namespace = v.namespace
      name      = v.name
      type      = "kubernetes.io/tls"
      data = {
        "tls.crt" = tls_locally_signed_cert.internal[k].cert_pem
        "tls.key" = tls_private_key.internal[k].private_key_pem
      }
    })
  }
}