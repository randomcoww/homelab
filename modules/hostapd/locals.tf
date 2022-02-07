locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, merge(var.template_params, {
      ht_capab = var.ht_capab
    }))
  ]
}