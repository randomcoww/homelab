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

  early_renewal_hours   = 8040
  validity_period_hours = 8760
  valid_principals      = concat([
    for v in values(var.ssh_hosts) :
    v.host_network.store.ip
  ], ["127.0.0.1"])
}

resource "sshca_client_cert" "ssh-client" {
  # Hack to conditionally create this if a key is passed in
  count = length(var.ssh_client_public_key) > 0 ? 1 : 0

  ca_key_algorithm   = tls_private_key.ssh-ca.algorithm
  ca_private_key_pem = tls_private_key.ssh-ca.private_key_pem
  public_key_openssh = var.ssh_client_public_key
  key_id             = var.user

  early_renewal_hours   = 168
  validity_period_hours = 336
  valid_principals      = []
}