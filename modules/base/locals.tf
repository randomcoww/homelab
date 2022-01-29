locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      users    = var.users
      hostname = var.hostname
    })
  ]
}