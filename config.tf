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
      wlan = {
        network = "192.168.62.0"
        cidr    = 24
        vlan_id = 90
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
      kea_peer              = 58080
      apiserver             = 58081
      controller_manager    = 50252
      scheduler             = 50251
      kubelet               = 50250
      etcd_client           = 58082
      etcd_peer             = 58083
      minio                 = 50256
      minio_console         = 50257
      internal_pxeboot_http = 80
      internal_pxeboot_api  = 50259
    }

    domains = {
      internal_mdns = "local"
      internal      = "fuzzybunny.internal"
      kubernetes    = "cluster.internal"
    }

    container_images = {
      kubelet                 = "ghcr.io/randomcoww/kubernetes:kubelet-v1.22.4"
      kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
      kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
      kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
      kube_proxy              = "ghcr.io/randomcoww/kubernetes:kube-proxy-v1.22.4"
      kube_addons_manager     = "ghcr.io/randomcoww/kubernetes-addon-manager:master"
      etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:latest"
      etcd                    = "ghcr.io/randomcoww/etcd:v3.5.1"
      kea                     = "ghcr.io/randomcoww/kea:2.0.0"
      tftpd                   = "ghcr.io/randomcoww/tftpd-ipxe:master"
      coredns                 = "docker.io/coredns/coredns:latest"
      flannel                 = "ghcr.io/randomcoww/flannel:v0.15.0"
      flannel-cni-plugin      = "rancher/mirrored-flannelcni-flannel-cni-plugin:v1.0.0"
      minio                   = "minio/minio:latest"
      hostapd                 = "ghcr.io/randomcoww/hostapd:latest"
      kapprover               = "ghcr.io/randomcoww/kapprover:latest"
      external_dns            = "k8s.gcr.io/external-dns/external-dns:v0.10.2"
      matchbox                = "quay.io/poseidon/matchbox:latest"
      syncthing               = "docker.io/syncthing/syncthing:latest"
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

    # http path to kubernetes matchbox #
    aws_region                                  = "us-west-2"
    kubernetes_cluster_name                     = "aio-prod"
    kubernetes_service_network_dns_netnum       = 10
    kubernetes_service_network_apiserver_netnum = 1
    static_pod_manifest_path                    = "/var/lib/kubelet/manifests"

    metallb_subnet = {
      newbit = 2
      netnum = 1
    }
    metallb_external_dns_netnum = 1
    metallb_pxeboot_netnum      = 2
  }


  # cleanup some of the "preprocess" entries above
  config = merge(local.preprocess, {
    users = {
      for user_name, user in local.preprocess.users :
      user_name => merge(user, lookup(var.users, user_name, {}))
    }

    networks = {
      for network_name, network in local.preprocess.networks :
      network_name => merge(network, try({
        prefix = "${network.network}/${network.cidr}"
      }, {}))
    }
  })
}