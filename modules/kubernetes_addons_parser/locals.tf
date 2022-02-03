locals {
  addon_manifests_hcl = {
    for file_name, manifests in var.addon_manifests :
    file_name => [
      for resource in compact(flatten(regexall("(?ms)(.*?)^---", "${manifests}\n---"))) :
      yamldecode(resource)
    ]
  }

  # force inject addonmanager.kubernetes.io/mode label
  modified_addon_manifests = {
    for file_name, manifests in local.addon_manifests_hcl :
    file_name => join("---\n", [
      for manifest in manifests :
      yamlencode(merge(manifest, {
        metadata = merge(manifest.metadata, {
          labels = merge({
            "addonmanager.kubernetes.io/mode" : var.default_create_mode
          }, lookup(manifest.metadata, "labels", {}))
        })
      }))
      if can(manifest.metadata)
    ])
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      addon_manifests      = local.modified_addon_manifests
      addon_manifests_path = var.addon_manifests_path
    })
  ]
}