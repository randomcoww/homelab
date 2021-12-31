resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_private_key" "ssh-host" {
  for_each = var.server_hosts

  algorithm   = tls_private_key.ssh-ca.algorithm
  ecdsa_curve = "P521"
}

resource "ssh_host_cert" "ssh-host" {
  for_each = var.server_hosts

  ca_key_algorithm   = tls_private_key.ssh-ca.algorithm
  ca_private_key_pem = tls_private_key.ssh-ca.private_key_pem
  public_key_openssh = tls_private_key.ssh-host[each.key].public_key_openssh
  key_id             = each.value.hostname

  early_renewal_hours   = 8040
  validity_period_hours = 8760
  valid_principals = compact([
    each.value.hostname,
    lookup(lookup(each.value.networks_by_key, "internal", {}), "ip", null),
    "127.0.0.1",
  ])
}

resource "ssh_client_cert" "ssh-client" {
  # Hack to conditionally create this if a key is passed in
  count = length(var.client_public_key) > 0 ? 1 : 0

  ca_key_algorithm   = tls_private_key.ssh-ca.algorithm
  ca_private_key_pem = tls_private_key.ssh-ca.private_key_pem
  public_key_openssh = var.client_public_key
  key_id             = var.user

  early_renewal_hours   = 168
  validity_period_hours = 336
  valid_principals      = []

  extensions = [
    "permit-agent-forwarding",
    "permit-port-forwarding",
    "permit-pty",
    "permit-user-rc",
  ]
}
