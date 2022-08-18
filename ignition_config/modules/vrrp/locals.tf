locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      haproxy_config_path    = var.haproxy_config_path
      keepalived_config_path = var.keepalived_config_path
    })
  ]
}