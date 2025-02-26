locals {
  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      butane_version = var.butane_version
      hostname       = var.hostname
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.butane_version
      passwd = {
        users = [
          {
            name         = "core"
            should_exist = false
          },
        ]
      }
    })
  ])
}