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
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "controller")
  }

  controller_templates = [
    "${path.module}/../templates/ignition/controller.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/containerd.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]

  worker_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "worker")
  }

  worker_templates = [
    "${path.module}/../templates/ignition/worker.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/storage.ign.tmpl",
    "${path.module}/../templates/ignition/containerd.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]
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
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "gateway")
  }

  gateway_templates = [
    "${path.module}/../templates/ignition/gateway.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/containerd.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]
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

  test_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "test")
  }

  test_templates = [
    "${path.module}/../templates/ignition/test.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/storage.ign.tmpl",
    "${path.module}/../templates/ignition/containerd.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]
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

  kvm_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "kvm")
  }

  kvm_templates = [
    "${path.module}/../templates/ignition/kvm.ign.tmpl",
    "${path.module}/../templates/ignition/vlan-network.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]
}

module "desktop-common" {
  source = "../modulesv2/desktop_common"

  user                 = var.desktop_user
  password             = var.desktop_password
  timezone             = var.desktop_timezone
  internal_ca_cert_pem = tls_self_signed_cert.internal-ca.cert_pem
  mtu                  = local.mtu
  networks             = local.networks

  desktop_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "desktop")
  }

  desktop_templates = [
    "${path.module}/../templates/ignition/desktop.ign.tmpl",
    "${path.module}/../templates/ignition/vlan-network.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/storage.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]
}