locals {
  params = {}
}

output "ignition" {
  value = {
    for host, params in var.hosts :
    host => [
      for f in fileset("templates/ignition", "*") :
      templatefile(f, merge(local.params, {
        tls_internal_ca   = replace(tls_self_signed_cert.internal-ca.cert_pem, "\n", "\\n")
        internal_tls_path = "/etc/pki/ca-trust/source/anchors/${var.name}.pem"
      }))
    ]
  }
}

output "kubernetes" {
  value = flatten([
    for f in fileset("templates/kubernetes", "*") : concat([
      for k, v in var.secrets :
      templatefile(f, {
        namespace = v.namespace
        name      = v.name
        type      = "kubernetes.io/tls"
        data = {
          "tls.crt" = tls_locally_signed_cert.internal[k].cert_pem
          "tls.key" = tls_private_key.internal[k].private_key_pem
        }
      })
    ])
  ])
}