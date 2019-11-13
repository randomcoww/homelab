module "kubernetes-common" {
  source = "../modulesv2/kubernetes_common"

  cluster_name          = "default-cluster-012"
  s3_backup_aws_region  = "us-west-2"
  s3_etcd_backup_bucket = "randomcoww-etcd-backup"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  controller_hosts = {
    controller-0 = {
      network = {
        store_ip = "192.168.127.219"
        store_if = "eth0"
        int_if   = "eth1"
        int_mac  = "52-54-00-1a-61-0a"
      }
    }
    controller-1 = {
      network = {
        store_ip = "192.168.127.220"
        store_if = "eth0"
        int_if   = "eth1"
        int_mac  = "52-54-00-1a-61-0b"
      }
    }
    controller-2 = {
      network = {
        store_ip = "192.168.127.221"
        store_if = "eth0"
        int_if   = "eth1"
        int_mac  = "52-54-00-1a-61-0c"
      }
    }
  }
  worker_hosts = {
    worker-0 = {
      network = {
        store_if = "eth0"
        int_if   = "eth1"
        int_mac  = "52-54-00-1a-61-1a"
      }
      disks = {
        pvworker = {
          host_device = "/dev/disk/by-path/pci-0000:00:17.0-ata-2"
          device      = "/dev/sda"
          format      = "ext4"
          mount_path  = "/pv"
        }
        # phy12 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy12-lun-0"
        #   device      = "/dev/sdb"
        #   format      = "ext4"
        #   mount_path  = "/minio/0"
        # }
        # phy13 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy13-lun-0"
        #   device      = "/dev/sdc"
        #   format      = "ext4"
        #   mount_path  = "/minio/1"
        # }
        # phy14 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy14-lun-0"
        #   device      = "/dev/sdd"
        #   format      = "ext4"
        #   mount_path  = "/minio/2"
        # }
        # phy15 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy15-lun-0"
        #   device      = "/dev/sde"
        #   format      = "ext4"
        #   mount_path  = "/minio/3"
        # }
        # phy16 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy16-lun-0"
        #   device      = "/dev/sdf"
        #   format      = "ext4"
        #   mount_path  = "/minio/4"
        # }
        # phy17 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy17-lun-0"
        #   device      = "/dev/sdg"
        #   format      = "ext4"
        #   mount_path  = "/minio/5"
        # }
        # phy18 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy18-lun-0"
        #   device      = "/dev/sdh"
        #   format      = "ext4"
        #   mount_path  = "/minio/6"
        # }
        # phy19 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy19-lun-0"
        #   device      = "/dev/sdi"
        #   format      = "ext4"
        #   mount_path  = "/minio/7"
        # }
        # phy20 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy20-lun-0"
        #   device      = "/dev/sdj"
        #   format      = "ext4"
        #   mount_path  = "/minio/8"
        # }
        # phy21 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy21-lun-0"
        #   device      = "/dev/sdk"
        #   format      = "ext4"
        #   mount_path  = "/minio/9"
        # }
        # phy22 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy22-lun-0"
        #   device      = "/dev/sdl"
        #   format      = "ext4"
        #   mount_path  = "/minio/10"
        # }
        # phy23 = {
        #   host_device = "/dev/disk/by-path/pci-0000:03:00.0-sas-exp0x5003048000a2973f-phy23-lun-0"
        #   device      = "/dev/sdm"
        #   format      = "ext4"
        #   mount_path  = "/minio/11"
        # }
      }
    }
    worker-1 = {
      network = {
        store_if = "eth0"
        int_if   = "eth1"
        int_mac  = "52-54-00-1a-61-1b"
      },
      disks = {
        pvworker = {
          host_device = "/dev/disk/by-path/pci-0000:00:17.0-ata-2"
          device      = "/dev/sda"
          format      = "ext4"
          mount_path  = "/pv"
        }
      }
    }
  }
}

module "gateway-common" {
  source = "../modulesv2/gateway_common"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  gateway_hosts = {
    gateway-0 = {
      network = {
        store_ip         = "192.168.127.217"
        store_if         = "eth0"
        lan_ip           = "192.168.63.217"
        lan_if           = "eth1"
        sync_ip          = "192.168.190.1"
        sync_if          = "eth2"
        wan_if           = "eth3"
        wan_mac          = "52-54-00-63-6e-b2"
        vwan_if          = "eth4"
        vwan_mac         = "52-54-00-63-6e-b3"
        vwan_route_table = 250
        int_if           = "eth5"
        int_mac          = "52-54-00-1a-61-2a"
      }
      kea_ha_role = "primary"
    }
    gateway-1 = {
      network = {
        store_ip         = "192.168.127.218"
        store_if         = "eth0"
        lan_ip           = "192.168.63.218"
        lan_if           = "eth1"
        sync_ip          = "192.168.190.2"
        sync_if          = "eth2"
        wan_if           = "eth3"
        wan_mac          = "52-54-00-63-6e-b1"
        vwan_if          = "eth4"
        vwan_mac         = "52-54-00-63-6e-b3"
        vwan_route_table = 250
        int_if           = "eth5"
        int_mac          = "52-54-00-1a-61-2b"
      }
      kea_ha_role = "standby"
    }
  }
}

##
## Write config to each matchbox host
## Hardcode each matchbox host until for_each module becomes available
##
module "ignition-kvm-0" {
  source = "../modulesv2/ignition"

  services          = local.services
  controller_params = module.kubernetes-common.controller_params
  worker_params     = module.kubernetes-common.worker_params
  gateway_params    = module.gateway-common.gateway_params
  renderer          = local.renderers.kvm-0
}

module "ignition-kvm-1" {
  source = "../modulesv2/ignition"

  services          = local.services
  controller_params = module.kubernetes-common.controller_params
  worker_params     = module.kubernetes-common.worker_params
  gateway_params    = module.gateway-common.gateway_params
  renderer          = local.renderers.kvm-1
}

# Test locally
module "ignition-local" {
  source = "../modulesv2/ignition"

  services          = local.services
  controller_params = module.kubernetes-common.controller_params
  worker_params     = module.kubernetes-common.worker_params
  gateway_params    = module.gateway-common.gateway_params
  renderer          = local.local_renderer
}

# Write admin kubeconfig file
resource "local_file" "kubeconfig-admin" {
  content = templatefile("${path.module}/../templates/manifest/kubeconfig_admin.yaml.tmpl", {
    cluster_name       = module.kubernetes-common.cluster_name
    ca_pem             = replace(base64encode(chomp(module.kubernetes-common.kubernetes_ca_pem)), "\n", "")
    cert_pem           = replace(base64encode(chomp(module.kubernetes-common.kubernetes_cert_pem)), "\n", "")
    private_key_pem    = replace(base64encode(chomp(module.kubernetes-common.kubernetes_private_key_pem)), "\n", "")
    apiserver_endpoint = module.kubernetes-common.apiserver_endpoint
  })
  filename = "output/${module.kubernetes-common.cluster_name}.kubeconfig"
}