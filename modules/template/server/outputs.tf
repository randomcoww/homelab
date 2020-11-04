locals {
  params = {}
}

output "ignition" {
  value = {
    for host, params in var.hosts :
    host => [
      for f in fileset("templates/ignition", "*") :
      templatefile(f, merge(local.params, {
        p                    = params
      }))
    ]
  }
}