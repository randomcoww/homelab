output "matchbox_ca_pem" {
  value = tls_self_signed_cert.matchbox-ca.cert_pem
}

output "matchbox_cert_pem" {
  value = tls_locally_signed_cert.matchbox-client.cert_pem
}

output "matchbox_private_key_pem" {
  value = tls_private_key.matchbox-client.private_key_pem
}

output "matchbox_rpc_endpoints" {
  value = {
    for k in keys(var.kvm_hosts) :
    k => "${var.kvm_hosts[k].network.host_tap_ip}:${var.services.renderer.ports.rpc}"
  }
}

output "matchbox_http_endpoints" {
  value = {
    for k in keys(var.kvm_hosts) :
    k => "${var.kvm_hosts[k].network.int_tap_ip}:${var.services.renderer.ports.http}"
  }
}