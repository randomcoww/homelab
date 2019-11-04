locals {
  controller_hosts = {
    controller-0 = {
      network = {
        store_ip = "192.168.127.219"
        store_if = "eth0"
      }
    }
    controller-1 = {
      network = {
        store_ip = "192.168.127.220"
        store_if = "eth0"
      }
    }
    controller-2 = {
      network = {
        store_ip = "192.168.127.221"
        store_if = "eth0"
      }
    }
  }

  worker_hosts = {
    worker-0 = {
      network = {
        store_if = "eth0"
      }
    }
    worker-1 = {
      network = {
        store_if = "eth0"
      }
    }
  }
}

# Do this to each provider until for_each module is available

module "kubernetes-test" {
  source = "../modulesv2/kubernetes"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images
  controller_hosts  = local.controller_hosts
  worker_hosts      = local.worker_hosts

  s3_backup_aws_region    = "us-west-2"
  s3_etcd_backup_bucket   = "randomcoww-etcd-backup"
  kubernetes_cluster_name = "default-cluster"

  ## Use local matchbox renderer launched with run_renderer.sh
  renderer = {
    endpoint        = "127.0.0.1:8081"
    cert_pem        = module.renderer.matchbox_cert_pem
    private_key_pem = module.renderer.matchbox_private_key_pem
    ca_pem          = module.renderer.matchbox_ca_pem
  }
}