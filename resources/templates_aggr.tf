locals {
  ignition_by_host = transpose(merge([
    for k in [
      lookup(module.template-kubernetes, "ignition_controller", {}),
      lookup(module.template-kubernetes, "ignition_worker", {}),
      lookup(module.template-gateway, "ignition", {}),
      lookup(module.template-ns, "ignition", {}),
      lookup(module.template-ssh, "ignition_server", {}),
      lookup(module.template-ssh, "ignition_client", {}),
      lookup(module.template-static-pod-logging, "ignition", {}),
      lookup(module.template-ingress, "ignition", {}),
      lookup(module.template-hypervisor, "ignition", {}),
      lookup(module.template-vm, "ignition", {}),
      lookup(module.template-kubelet, "ignition", {}),
      lookup(module.template-client, "ignition", {}),
      lookup(module.template-laptop, "ignition", {}),
      lookup(module.template-server, "ignition", {}),
      lookup(module.template-base, "ignition", {}),
      lookup(module.template-fancontrol, "ignition", {}),
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

  kubernetes_pre1 = [
    for j in flatten([
      for i in concat(
        lookup(module.template-ingress, "kubernetes", []),
        lookup(module.template-secrets, "kubernetes", []),
        lookup(module.template-kubernetes, "kubernetes", []),
        lookup(module.template-gateway, "kubernetes", []),
        lookup(module.template-static-pod-logging, "kubernetes", []),
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