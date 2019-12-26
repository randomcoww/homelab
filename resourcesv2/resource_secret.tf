##
## SSH CA for all hosts
##
resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

## ssh ca
resource "local_file" "ssh-ca-key" {
  content  = chomp(tls_private_key.ssh-ca.private_key_pem)
  filename = "output/ssh-ca-key.pem"
}

##
## internal CA for ingress
##
resource "tls_private_key" "internal-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "internal-ca" {
  key_algorithm         = tls_private_key.internal-ca.algorithm
  private_key_pem       = tls_private_key.internal-ca.private_key_pem
  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = local.domains.internal
    organization = local.domains.internal
  }

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

resource "tls_private_key" "internal" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "internal" {
  key_algorithm   = tls_private_key.internal.algorithm
  private_key_pem = tls_private_key.internal.private_key_pem

  subject {
    common_name  = local.domains.internal
    organization = local.domains.internal
  }

  dns_names = [
    "*.${local.domains.internal}",
  ]
}

resource "tls_locally_signed_cert" "internal" {
  cert_request_pem   = tls_cert_request.internal.cert_request_pem
  ca_key_algorithm   = tls_private_key.internal-ca.algorithm
  ca_private_key_pem = tls_private_key.internal-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.internal-ca.cert_pem

  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

##
## local matchbox
##
resource "tls_private_key" "local-matchbox-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "local-matchbox-ca" {
  key_algorithm         = tls_private_key.local-matchbox-ca.algorithm
  private_key_pem       = tls_private_key.local-matchbox-ca.private_key_pem
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

resource "tls_private_key" "local-matchbox" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "local-matchbox" {
  key_algorithm   = tls_private_key.local-matchbox.algorithm
  private_key_pem = tls_private_key.local-matchbox.private_key_pem
  ip_addresses = [
    "127.0.0.1"
  ]

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
  }
}

resource "tls_locally_signed_cert" "local-matchbox" {
  cert_request_pem   = tls_cert_request.local-matchbox.cert_request_pem
  ca_key_algorithm   = tls_private_key.local-matchbox-ca.algorithm
  ca_private_key_pem = tls_private_key.local-matchbox-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.local-matchbox-ca.cert_pem

  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

locals {
  ## Matchbox instance to write configs to
  ## This needs to be passed in by hostname (e.g. -var=renderer=kvm-0) for now
  ## Dynamic provider support might resolse this
  local_renderer = {
    endpoint        = "127.0.0.1:${local.services.local_renderer.ports.rpc}"
    cert_pem        = tls_locally_signed_cert.local-matchbox.cert_pem
    private_key_pem = tls_private_key.local-matchbox.private_key_pem
    ca_pem          = tls_self_signed_cert.local-matchbox-ca.cert_pem
  }
}

##
## minio user-pass
##
resource "random_password" "minio-user" {
  length  = 30
  special = false
}

resource "random_password" "minio-password" {
  length  = 30
  special = false
}

##
## grafana user-pass
##
resource "random_password" "grafana-user" {
  length  = 30
  special = false
}

resource "random_password" "grafana-password" {
  length  = 30
  special = false
}

##
## Write local files
##
resource "local_file" "matchbox-ca-pem" {
  content  = chomp(tls_self_signed_cert.local-matchbox-ca.cert_pem)
  filename = "output/local-renderer/ca.crt"
}

resource "local_file" "matchbox-private-key-pem" {
  content  = chomp(tls_private_key.local-matchbox.private_key_pem)
  filename = "output/local-renderer/server.key"
}

resource "local_file" "matchbox-cert-pem" {
  content  = chomp(tls_locally_signed_cert.local-matchbox.cert_pem)
  filename = "output/local-renderer/server.crt"
}