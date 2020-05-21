module "kubernetes-common" {
  source = "../modulesv2/kubernetes_common"

  cluster_name          = local.kubernetes_cluster_name
  s3_backup_aws_region  = local.s3_backup_aws_region
  s3_etcd_backup_bucket = local.s3_etcd_backup_bucket

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  controller_templates = local.components.controller.templates
  controller_hosts = {
    for k in local.components.controller.nodes :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
  }

  worker_templates = local.components.worker.templates
  worker_hosts = {
    for k in local.components.worker.nodes :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
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

  gateway_templates = local.components.gateway.templates
  gateway_hosts = {
    for k in local.components.gateway.nodes :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
  }
}

module "test-common" {
  source = "../modulesv2/test_common"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  test_templates = local.components.test.templates
  test_hosts = {
    for k in local.components.test.nodes :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
  }
}

module "kvm-common" {
  source = "../modulesv2/kvm_common"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  kvm_templates = local.components.kvm.templates
  kvm_hosts = {
    for k in local.components.kvm.nodes :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
  }
}

module "desktop-common" {
  source = "../modulesv2/desktop_common"

  user                 = var.desktop_user
  password             = var.desktop_password
  timezone             = var.desktop_timezone
  internal_ca_cert_pem = tls_self_signed_cert.internal-ca.cert_pem
  mtu                  = local.mtu
  networks             = local.networks

  desktop_templates = local.components.desktop.templates
  desktop_hosts = {
    for k in local.components.desktop.nodes :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
  }
}