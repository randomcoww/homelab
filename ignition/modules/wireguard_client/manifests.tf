locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version    = var.ignition_version
      private_key         = var.private_key
      public_key          = var.public_key
      endpoint            = var.endpoint
      address             = var.address
      table_id            = 1000
      table_priority_base = 30000
      firewall_mark       = "0x8888"
      interface           = "wg0"
      uid                 = var.uid
    })
  ]
}