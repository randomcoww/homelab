module "ssh-common" {
  source = "../modulesv2/ssh_common"

  user                  = local.user
  networks              = local.networks
  ssh_client_public_key = var.ssh_client_public_key
  ssh_templates         = local.components.ssh.templates
  ssh_hosts = {
    for k in local.components.ssh.nodes :
    k => merge(local.hosts[k], {
      host_network = local.host_network_by_type[k]
    })
  }
}

module "kubernetes-common" {
  source = "../modulesv2/kubernetes_common"

  cluster_name          = local.kubernetes_cluster_name
  s3_backup_aws_region  = local.s3_backup_aws_region
  s3_etcd_backup_bucket = local.s3_etcd_backup_bucket

  user             = local.user
  mtu              = local.mtu
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images

  controller_templates = local.components.controller.templates
  controller_hosts = {
    for k in local.components.controller.nodes :
    k => merge(local.hosts[k], {
      host_network = local.host_network_by_type[k]
    })
  }

  worker_templates = local.components.worker.templates
  worker_hosts = {
    for k in local.components.worker.nodes :
    k => merge(local.hosts[k], {
      host_network = local.host_network_by_type[k]
    })
  }
}

module "gateway-common" {
  source = "../modulesv2/gateway_common"

  user               = local.user
  mtu                = local.mtu
  networks           = local.networks
  loadbalancer_pools = local.loadbalancer_pools
  services           = local.services
  domains            = local.domains
  container_images   = local.container_images

  gateway_templates = local.components.gateway.templates
  gateway_hosts = {
    for k in local.components.gateway.nodes :
    k => merge(local.hosts[k], {
      host_network = local.host_network_by_type[k]
    })
  }
}

module "test-common" {
  source = "../modulesv2/test_common"

  user             = local.user
  mtu              = local.mtu
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images

  test_templates = local.components.test.templates
  test_hosts = {
    for k in local.components.test.nodes :
    k => merge(local.hosts[k], {
      host_network = local.host_network_by_type[k]
    })
  }
}

module "kvm-common" {
  source = "../modulesv2/kvm_common"

  user             = local.user
  mtu              = local.mtu
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images
  image_device     = local.image_device

  kvm_templates = local.components.kvm.templates
  kvm_hosts = {
    for k in local.components.kvm.nodes :
    k => merge(local.hosts[k], {
      host_network = local.host_network_by_type[k]
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
      host_network = local.host_network_by_type[k]
    })
  }
}