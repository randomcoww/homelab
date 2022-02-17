locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, merge(var.roaming_members[var.host_key], {
      ssid       = var.ssid
      passphrase = var.passphrase
      ht_capab   = var.ht_capab
      members    = values(var.roaming_members)
    }))
  ]
}