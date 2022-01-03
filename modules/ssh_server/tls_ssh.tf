resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_private_key" "ssh-host" {
  algorithm   = var.ca.ssh.algorithm
  ecdsa_curve = "P521"
}

resource "ssh_host_cert" "ssh-host" {
  ca_key_algorithm   = var.ca.ssh.algorithm
  ca_private_key_pem = var.ca.ssh.private_key_pem
  public_key_openssh = tls_private_key.ssh-host.public_key_openssh
  key_id             = var.hostname

  early_renewal_hours   = 8040
  validity_period_hours = 8760
  valid_principals = concat(["127.0.0.1", var.hostname], [
    for interface in values(local.interfaces) :
    [
      for tap in value(interface.taps) :
      tap.ip
    ]
  ])
}