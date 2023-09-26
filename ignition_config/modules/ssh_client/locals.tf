locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      public_key_openssh = var.public_key_openssh
    })
  ]
}