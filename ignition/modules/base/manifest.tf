locals {
  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version = var.ignition_version
      hostname         = var.hostname
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.ignition_version
      passwd = {
        users = concat(var.users, [
          {
            name         = "core"
            should_exist = false
          },
        ])
      }
    })
  ])
}