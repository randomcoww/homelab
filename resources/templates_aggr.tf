locals {
  ignition_by_host = transpose(merge([
    for k in [
      lookup(module.template-kubernetes, "ignition_controller", {}),
      lookup(module.template-kubernetes, "ignition_worker", {}),
      lookup(module.template-gateway, "ignition", {}),
      lookup(module.template-ns, "ignition", {}),
      lookup(module.template-ssh, "ignition_server", {}),
      lookup(module.template-ssh, "ignition_client", {}),
      lookup(module.template-ingress, "ignition", {}),
      lookup(module.template-hypervisor, "ignition", {}),
      lookup(module.template-vm, "ignition", {}),
      lookup(module.template-kubelet, "ignition", {}),
      lookup(module.template-client, "ignition", {}),
      lookup(module.template-laptop, "ignition", {}),
      lookup(module.template-server, "ignition", {}),
      lookup(module.template-base, "ignition", {}),
    ] :
    transpose(k)
    ]...
  ))

  pxeboot_hosts = {
    for host, params in local.aggr_hosts :
    host => {
      templates     = lookup(local.ignition_by_host, host, [])
      kernel_image  = lookup(params, "kernel_image", "")
      initrd_images = lookup(params, "initrd_images", [])
      kernel_params = lookup(params, "kernel_params", [])
      selector      = lookup(params, "selector", {})
    }
  }

  pxeboot_hosts_by_hypervisor = {
    for host, params in local.aggr_hosts :
    host => {
      for g in params.libvirt_domains :
      g.node => local.pxeboot_hosts[g.node]
    }
  }

  pxeboot_hosts_by_local_rederer = {
    for host in local.local_renderer_hosts_include :
    host => lookup(local.pxeboot_hosts, host, {})
  }

  kubernetes_pre1 = [
    for j in flatten([
      for i in concat(
        lookup(module.template-ingress, "kubernetes", []),
        lookup(module.template-secrets, "kubernetes", []),
        lookup(module.template-kubernetes, "kubernetes", []),
        lookup(module.template-gateway, "kubernetes", []),
      ) :
      regexall("(?ms)(.*?)^---", "${i}\n---")
    ]) :
    try(yamldecode(j), {})
  ]

  kubernetes_namespaces = nonsensitive({
    for k, v in {
      for j in local.kubernetes_pre1 :
      "${j.kind}-${lookup(j.metadata, "namespace", "default")}-${j.metadata.name}" => [yamlencode(j)]...
      if lookup(j, "kind", null) == "Namespace"
    } :
    k => flatten(v)[0]
  })

  kubernetes_manifests = nonsensitive({
    for k, v in {
      for j in local.kubernetes_pre1 :
      "${j.kind}-${lookup(j.metadata, "namespace", "default")}-${j.metadata.name}" => [yamlencode(j)]...
      if lookup(j, "kind", "Namespace") != "Namespace"
    } :
    k => flatten(v)[0]
  })
}