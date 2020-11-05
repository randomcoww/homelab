locals {
  ignition_by_host = transpose(merge([
    for k in [
      lookup(module.template-kubernetes, "ignition_controller", {}),
      lookup(module.template-kubernetes, "ignition_worker", {}),
      lookup(module.template-gateway, "ignition", {}),
      lookup(module.template-test, "ignition", {}),
      lookup(module.template-ssh, "ignition_server", {}),
      lookup(module.template-ssh, "ignition_client", {}),
      lookup(module.template-static-pod-logging, "ignition", {}),
      lookup(module.template-ingress, "ignition", {}),
      lookup(module.template-hypervisor, "ignition", {}),
      lookup(module.template-vm, "ignition", {}),
      lookup(module.template-client, "ignition", {}),
      lookup(module.template-server, "ignition", {}),
      lookup(module.template-base, "ignition", {}),
    ] :
    transpose(k)
    ]...
  ))

  pxeboot_by_host = {
    for host, params in local.aggr_hosts :
    host => {
      for g in params.libvirt_domains :
      g.node => {
        templates     = local.ignition_by_host[g.node]
        kernel_image  = params.kernel_image
        initrd_images = params.initrd_images
        kernel_params = g.host.kernel_params
        selector      = g.host.metadata
      }
    }
  }

  kubernetes_addons = [
    for k in compact([
      for j in flatten([
        for i in concat(
          lookup(module.template-ingress, "kubernetes", []),
          lookup(module.template-secrets, "kubernetes", []),
          lookup(module.template-kubernetes, "kubernetes", []),
        ) :
        regexall("(?ms)(.*?)^---", "${i}\n---")
      ]) :
      trimspace(j)
    ]) :
    try(yamldecode(k), {})
  ]

  kubernetes_addons_local = [
    for k in compact([
      for j in flatten([
        for i in concat(
          lookup(module.template-gateway, "kubernetes", []),
          lookup(module.template-static-pod-logging, "kubernetes", []),
        ) :
        regexall("(?ms)(.*?)^---", "${i}\n---")
      ]) :
      trimspace(j)
    ]) :
    try(yamldecode(k), {})
  ]
}