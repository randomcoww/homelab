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
    k => "${var.kvm_hosts[k].host_network.store.ip}:${var.services.renderer.ports.rpc}"
  }
}

output "libvirt_endpoints" {
  value = {
    for k in keys(var.kvm_hosts) :
    k => "qemu+ssh://${var.user}@${var.kvm_hosts[k].host_network.store.ip}/system"
  }
}