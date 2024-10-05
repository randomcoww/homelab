locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version    = var.ignition_version
      private_key         = var.private_key
      public_key          = var.public_key
      endpoint            = var.endpoint
      address             = split(",", var.address)
      dns                 = var.dns
      allowed_ips         = split(",", var.allowed_ips)
      table_id            = 1000
      table_priority_base = 30000
      fw_mark             = var.fw_mark
      interface           = "wg0"
      uid                 = var.uid
    })
  ]
}