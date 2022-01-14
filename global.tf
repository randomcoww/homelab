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
          "libvirt",
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
          "libvirt",
        ]
      }
    }

    networks = {
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
      kubernetes_pod = {
        network = "10.244.0.0"
        cidr    = 16
      }
      kubernetes_service = {
        network = "10.96.0.0"
        cidr    = 12
      }
    }

    ports = {
      kea_peer    = 58080
      apiserver   = 58081
      etcd_client = 58082
      etcd_peer   = 58083
    }

    domains = {
      internal_mdns = "local"
      internal      = "fuzzybunny.internal"
      kubernetes    = "cluster.internal"
    }

    container_images = {
      conntrackd              = "ghcr.io/randomcoww/conntrackd:latest"
      kubelet                 = "ghcr.io/randomcoww/kubernetes:kubelet-v1.22.4"
      kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
      kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
      kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
      hyperkube               = "ghcr.io/randomcoww/kubernetes:kubelet-v1.22.4"
      kube_proxy              = "ghcr.io/randomcoww/kubernetes:kube-proxy-v1.22.4"
      etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:latest"
      etcd                    = "ghcr.io/randomcoww/etcd:v3.5.1"
      kea                     = "ghcr.io/randomcoww/kea:2.0.0"
      tftpd                   = "ghcr.io/randomcoww/tftpd-ipxe:master"
      coredns                 = "docker.io/coredns/coredns:latest"
    }

    ca = {
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

    # http path to kubernetes matchbox
    pxeboot_file_name = "http://192.168.126.127/boot.ipxe"

    # kubernetes external dns
    internal_dns_ip    = "192.168.126.126"
    etcd_cluster_token = "22011"
    aws_region         = "us-west-2"
  }
}

# SSH CA #
resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
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

# kubernetes #
module "kubernetes-common" {
  source              = "./modules/kubernetes_common"
  etcd_s3_backup_user = "etcd_s3_backup_user-220011"
  etcd_s3_backup_key  = "randomcoww-etcd-backup/22011"
}