locals {
  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      butane_version = var.butane_version
      upstream_dns   = var.upstream_dns
    })
  ])
}