output "templates" {
  value = {
    for host, params in var.internal_tls_hosts :
    host => [
      for template in var.internal_tls_templates :
      templatefile(template, {
        tls_internal_ca   = replace(tls_self_signed_cert.internal-ca.cert_pem, "\n", "\\n")
        internal_tls_path = "/etc/pki/ca-trust/source/anchors"
      })
    ]
  }
}

output "addons" {
  value = merge({
    ## Master access permissions
    bootstrap = templatefile(var.addon_templates.bootstrap, {
    })
    ## Internal TLS for ingress
    internal-tls-secret = templatefile(var.addon_templates.secret, {
      namespace = "default"
      name      = "internal-tls"
      type      = "kubernetes.io/tls"
      data = {
        "tls.crt" = tls_locally_signed_cert.internal.cert_pem
        "tls.key" = tls_private_key.internal.private_key_pem
      }
    })
    ## Metallb network
    metallb-network = templatefile(var.addon_templates.metallb_network, {
      loadbalancer_pools = var.loadbalancer_pools
    })
    },
    {
      for k in [
        "loki",
      ] :
      k => templatefile(var.addon_templates[k], {
        namespace        = "default"
        container_images = var.container_images
        services         = var.services
        networks         = var.networks
        domains          = var.domains
      })
    },
    {
      for k in [
        "kube-proxy",
        "kapprover",
        "flannel",
        "coredns",
      ] :
      k => templatefile(var.addon_templates[k], {
        namespace        = "kube-system"
        container_images = var.container_images
        services         = var.services
        networks         = var.networks
        domains          = var.domains
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
  })
}