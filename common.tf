locals {
  common = {
    admin_user = "fcos"
    vlans = {
      lan = {
        network = "192.168.126.0/24"
        vlan_id = 1
      }
    }
    domains = {
      mdns = "local"
    }
  }
}

# SSH CA #
resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

# matchbox CA #
resource "tls_private_key" "matchbox-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "matchbox-ca" {
  key_algorithm   = tls_private_key.matchbox-ca.algorithm
  private_key_pem = tls_private_key.matchbox-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
  }

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

# libvirt CA #
resource "tls_private_key" "libvirt-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "libvirt-ca" {
  key_algorithm   = tls_private_key.libvirt-ca.algorithm
  private_key_pem = tls_private_key.libvirt-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = "libvirt"
    organization = "libvirt"
  }

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}