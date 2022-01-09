# these variables are processed into local.config.<entry>
locals {
  preprocess = {
    users = {
      admin = {
        name = "fcos"
        groups = [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel",
        ]
      }
      client = {
        name     = "randomcoww"
        uid      = 10000
        home_dir = "/var/home/randomcoww"
        groups = [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel",
        ]
      }
    }

    networks = {
      internal = {
        network = "192.168.224.0"
        cidr    = 24
      }
      lan = {
        network = "192.168.126.0"
        cidr    = 23
        vlan_id = 1
      }
      sync = {
        network = "192.168.190.0"
        cidr    = 29
        vlan_id = 60
      }
      wan = {
        vlan_id = 30
      }
    }

    domains = {
      internal_mdns = "local"
      internal      = "fuzzybunny.internal"
    }

    container_images = {
      conntrackd = "ghcr.io/randomcoww/conntrackd:latest"
      kubelet    = "ghcr.io/randomcoww/kubernetes:kubelet-v1.22.4"
      kea        = "docker.io/randomcoww/kea:latest"
      tftpd      = "docker.io/randomcoww/tftpd-ipxe:latest"
      coredns    = "docker.io/coredns/coredns:1.8.0"
      keepalived = "docker.io/randomcoww/keepalived:latest"
      matchbox   = "quay.io/poseidon/matchbox:latest"
    }

    system_image_tags = {
      server = "fedora-coreos-35.20220107.0"
    }

    ca = {
      matchbox = {
        algorithm       = tls_private_key.matchbox-ca.algorithm
        private_key_pem = tls_private_key.matchbox-ca.private_key_pem
        cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem
      }
      libvirt = {
        algorithm       = tls_private_key.libvirt-ca.algorithm
        private_key_pem = tls_private_key.libvirt-ca.private_key_pem
        cert_pem        = tls_self_signed_cert.libvirt-ca.cert_pem
      }
      ssh = {
        algorithm          = tls_private_key.ssh-ca.algorithm
        private_key_pem    = tls_private_key.ssh-ca.private_key_pem
        public_key_openssh = tls_private_key.ssh-ca.public_key_openssh
      }
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

# matchbox cient #
resource "tls_private_key" "matchbox-client" {
  algorithm   = tls_private_key.matchbox-ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "matchbox-client" {
  key_algorithm   = tls_private_key.matchbox-client.algorithm
  private_key_pem = tls_private_key.matchbox-client.private_key_pem

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
  }
}

resource "tls_locally_signed_cert" "matchbox-client" {
  cert_request_pem   = tls_cert_request.matchbox-client.cert_request_pem
  ca_key_algorithm   = tls_private_key.matchbox-ca.algorithm
  ca_private_key_pem = tls_private_key.matchbox-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# libvirt client #
resource "tls_private_key" "libvirt-client" {
  algorithm   = tls_private_key.libvirt-ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "libvirt-client" {
  key_algorithm   = tls_private_key.libvirt-client.algorithm
  private_key_pem = tls_private_key.libvirt-client.private_key_pem

  subject {
    common_name = "libvirt"
  }
}

resource "tls_locally_signed_cert" "libvirt-client" {
  cert_request_pem   = tls_cert_request.libvirt-client.cert_request_pem
  ca_key_algorithm   = tls_private_key.libvirt-ca.algorithm
  ca_private_key_pem = tls_private_key.libvirt-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.libvirt-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# SSH client #
resource "ssh_client_cert" "ssh-client" {
  ca_key_algorithm      = tls_private_key.ssh-ca.algorithm
  ca_private_key_pem    = tls_private_key.ssh-ca.private_key_pem
  key_id                = var.ssh_client.key_id
  public_key_openssh    = var.ssh_client.public_key
  early_renewal_hours   = var.ssh_client.early_renewal_hours
  validity_period_hours = var.ssh_client.validity_period_hours
  valid_principals      = []

  extensions = [
    "permit-agent-forwarding",
    "permit-port-forwarding",
    "permit-pty",
    "permit-user-rc",
  ]
}