locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version    = var.ignition_version
      private_key         = var.private_key
      public_key          = var.public_key
      endpoint            = var.endpoint
      address             = var.address
      table_id            = 230
      table_priority_base = 32760
      firewall_mark       = "0xa22a61a9"
      mtu                 = 1420
      interface           = "wg0"
    })
  ]
}