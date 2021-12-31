output "ignition" {
  value = {
    for name, host in var.hosts :
    name => [
      for f in fileset(".", "${path.module}/ignition/*") :
      templatefile(f, merge(host,
        local.host_interfaces[name],
        local.host_certs[name],
      ))
    ]
  }
}

output "matchbox_rpc_endpoints" {
  value = {
    for host, params in var.hosts :
    host => {
      rpc_endpoints    = "${params.networks_by_key.internal.ip}:${var.services.renderer.ports.rpc}"
      http_endpoint = join(":", host.interfaces.internal.internal.ip, host.matchbox_http_port)
      cert_pem        = tls_locally_signed_cert.matchbox-client.cert_pem
      private_key_pem = tls_private_key.matchbox-client.private_key_pem
      ca_pem          = tls_self_signed_cert.matchbox-ca.cert_pem
    }
  }
}

output "libvirt_endpoints" {
  value = {
    for host, params in var.hosts :
    host => {
      endpoints        = "qemu://${params.networks_by_key.internal.ip}/system"
      cert_pem        = tls_locally_signed_cert.libvirt-client.cert_pem
      private_key_pem = tls_private_key.libvirt-client.private_key_pem
      ca_pem          = tls_self_signed_cert.libvirt-ca.cert_pem
    }
  }
}