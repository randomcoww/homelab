locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version        = var.ignition_version
      external_interface_name = var.external_interface_name
    })
  ]
}