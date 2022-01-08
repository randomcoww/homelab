locals {
  config = {
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
        name = "randomcoww"
        uid  = 10000
        home = "/var/home/randomcoww"
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
    # assign names for guest interfaces by order
    # libvirt assigns names ens2, ens3 ... ensN in order defined in domain XML
    interface_device_order = ["lan", "sync", "wan", "internal"]
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