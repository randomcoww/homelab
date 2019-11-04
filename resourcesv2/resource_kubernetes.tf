locals {
  kubernetes_cluster_name = "default-cluster"

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
  kubernetes_cluster_name = local.kubernetes_cluster_name

  ## Use local matchbox renderer launched with run_renderer.sh
  renderer = {
    endpoint        = "127.0.0.1:8081"
    cert_pem        = module.renderer.matchbox_cert_pem
    private_key_pem = module.renderer.matchbox_private_key_pem
    ca_pem          = module.renderer.matchbox_ca_pem
  }
}

resource "local_file" "kubeconfig-admin" {
  content = templatefile("${path.module}/../templates/manifest/kubeconfig_admin.yaml.tmpl", {
    cluster_name       = local.kubernetes_cluster_name
    ca_pem             = replace(base64encode(chomp(module.kubernetes-test.kubernetes_ca_pem)), "\n", "")
    cert_pem           = replace(base64encode(chomp(module.kubernetes-test.kubernetes_cert_pem)), "\n", "")
    private_key_pem    = replace(base64encode(chomp(module.kubernetes-test.kubernetes_private_key_pem)), "\n", "")
    apiserver_endpoint = module.kubernetes-test.apiserver_endpoint
  })
  filename = "./output/kubernetes/${local.kubernetes_cluster_name}.kubeconfig"
}