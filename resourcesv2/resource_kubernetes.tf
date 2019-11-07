locals {
  controller_hosts = {
    controller-0 = {
      network = {
        store_ip = "192.168.127.219"
        store_if = "eth0"
        int_mac  = "52-54-00-1a-61-0a"
      }
    }
    controller-1 = {
      network = {
        store_ip = "192.168.127.220"
        store_if = "eth0"
        int_mac  = "52-54-00-1a-61-0b"
      }
    }
    controller-2 = {
      network = {
        store_ip = "192.168.127.221"
        store_if = "eth0"
        int_mac  = "52-54-00-1a-61-0c"
      }
    }
  }

  worker_hosts = {
    worker-0 = {
      network = {
        store_if = "eth0"
        int_mac  = "52-54-00-1a-61-1a"
      }
    }
    worker-1 = {
      network = {
        store_if = "eth0"
        int_mac  = "52-54-00-1a-61-1b"
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

  cluster_name          = "default-cluster"
  s3_backup_aws_region  = "us-west-2"
  s3_etcd_backup_bucket = "randomcoww-etcd-backup"

  # Render to one of KVM host matchbox instances
  renderer = local.renderers[var.renderer]
}

# Write admin kubeconfig file
resource "local_file" "kubeconfig-admin" {
  content = templatefile("${path.module}/../templates/manifest/kubeconfig_admin.yaml.tmpl", {
    cluster_name       = module.kubernetes-test.cluster_name
    ca_pem             = module.kubernetes-test.kubernetes_ca_pem_base64
    cert_pem           = module.kubernetes-test.kubernetes_cert_pem_base64
    private_key_pem    = module.kubernetes-test.kubernetes_private_key_pem_base64
    apiserver_endpoint = module.kubernetes-test.apiserver_endpoint
  })
  filename = "output/${module.kubernetes-test.cluster_name}.kubeconfig"
}