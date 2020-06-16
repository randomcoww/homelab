##
## Write config to each matchbox host
## Hardcode each matchbox host until for_each module becomes available
##
module "ignition-kvm-0" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = {
    for h in local.hosts.kvm-0.guests :
    h => {
      templates = flatten([
        for k in [
          module.kubernetes-common.controller_templates,
          module.kubernetes-common.worker_templates,
          module.gateway-common.templates,
          module.test-common.templates,
          module.ssh-common.templates,
          module.static-pod-logging.templates,
          module.tls-secrets.templates,
        ] :
        k[h]
        if lookup(k, h, null) != null
      ])
      selector = lookup(local.host_network_by_type[h], "int", {})
    }
  }

  services      = local.services
  renderer      = module.kvm-common.matchbox_rpc_endpoints.kvm-0
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

module "ignition-kvm-1" {
  source = "../modulesv2/ignition_pxe"

  ignition_params = {
    for h in local.hosts.kvm-1.guests :
    h => {
      templates = flatten([
        for k in [
          module.kubernetes-common.controller_templates,
          module.kubernetes-common.worker_templates,
          module.gateway-common.templates,
          module.test-common.templates,
          module.ssh-common.templates,
          module.static-pod-logging.templates,
          module.tls-secrets.templates,
        ] :
        k[h]
        if lookup(k, h, null) != null
      ])
      selector = lookup(local.host_network_by_type[h], "int", {})
    }
  }

  services      = local.services
  renderer      = module.kvm-common.matchbox_rpc_endpoints.kvm-1
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
        for k in [
          module.ssh-common.templates,
          module.kvm-common.templates,
          module.desktop-common.templates,
          module.tls-secrets.templates,
        ] :
        k[h]
        if lookup(k, h, null) != null
      ])
    }
  }

  renderer = local.local_renderer
}

module "generic-manifest-local" {
  source = "../modulesv2/generic_manifest"

  generic_params = merge(
    module.gateway-common.addons,
    module.kubernetes-common.addons,
    # module.secrets.addons,
    # module.tls-secrets.addons,
    # module.ssh-common.addons,
    module.static-pod-logging.addons,
    # module.test-common.addons,
  )

  renderer = local.local_renderer
}