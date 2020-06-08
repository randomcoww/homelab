output "addons" {
  value = merge(
    {
      for k, v in var.secrets :
      "${v.namespace}-${v.name}" => templatefile(var.addon_templates.secret, {
        name      = v.name
        namespace = v.namespace
        data      = v.data
        type      = "Opaque"
      })
    }
  )
}