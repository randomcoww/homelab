##
## Write config to each matchbox host
## Hardcode each matchbox host until for_each module becomes available
##
locals {
  common_templates = [
    module.kubernetes-common.controller_templates,
    module.kubernetes-common.worker_templates,
    module.gateway-common.templates,
    module.test-common.templates,
    module.ssh-common.templates,
    module.static-pod-logging.templates,
    module.tls-secrets.templates,
    module.kvm-common.templates,
    module.hypervisor.templates,
  ]

  addons = merge(
    module.gateway-common.addons,
    module.kubernetes-common.addons,
    module.secrets.addons,
    module.tls-secrets.addons,
    module.ssh-common.addons,
    module.static-pod-logging.addons,
    module.test-common.addons,
  )
}

module "ignition-kvm-0" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = merge([
    for params in values(local.aggr_hosts.kvm-0.libvirt_domains) :
    {
      for h in params.nodes :
      h => {
        templates = flatten([
          for k in local.common_templates :
          lookup(k, h, [])
        ])
        selector = lookup(local.aggr_hosts[h].networks_by_key, "int", {})
      }
    }]...
  )

  services      = local.services
  renderer      = module.hypervisor.matchbox_rpc_endpoints.kvm-0
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

module "ignition-kvm-1" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = merge([
    for params in values(local.aggr_hosts.kvm-1.libvirt_domains) :
    {
      for h in params.nodes :
      h => {
        templates = flatten([
          for k in local.common_templates :
          lookup(k, h, [])
        ])
        selector = lookup(local.aggr_hosts[h].networks_by_key, "int", {})
      }
    }]...
  )

  services      = local.services
  renderer      = module.hypervisor.matchbox_rpc_endpoints.kvm-1
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

module "ignition-desktop" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = merge([
    for params in values(local.aggr_hosts.desktop.libvirt_domains) :
    {
      for h in params.nodes :
      h => {
        templates = flatten([
          for k in local.common_templates :
          lookup(k, h, [])
        ])
        selector = lookup(local.aggr_hosts[h].networks_by_key, "int", {})
      }
    }]...
  )

  services      = local.services
  renderer      = module.hypervisor.matchbox_rpc_endpoints.desktop
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

# Build and test environment
module "ignition-local" {
  source = "../modulesv2/ignition_local"

  ignition_params = {
    for h in local.local_renderer_hosts_include :
    h => {
      templates = flatten([
        for k in concat(local.common_templates, [
          module.desktop-common.templates,
        ]) :
        lookup(k, h, [])
      ])
    }
  }

  renderer = local.local_renderer
}

module "generic-manifest-local" {
  source = "../modulesv2/generic_manifest"

  generic_params = local.addons
  renderer       = local.local_renderer
}