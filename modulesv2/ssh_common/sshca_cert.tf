resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_private_key" "ssh-host" {
  for_each = var.ssh_hosts

  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "sshca_host_cert" "ssh-host" {
  for_each = var.ssh_hosts

  ca_key_algorithm   = tls_private_key.ssh-ca.algorithm
  ca_private_key_pem = tls_private_key.ssh-ca.private_key_pem
  public_key_openssh = tls_private_key.ssh-host[each.key].public_key_openssh
  key_id             = each.key

  validity_period_hours = 8760

  valid_principals = [
    each.key,
    each.value.host_network.store.ip,
  ]
}