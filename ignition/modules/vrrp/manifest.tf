locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version = var.ignition_version
      haproxy_path     = var.haproxy_path
      keepalived_path  = var.keepalived_path
    })
  ]
}