locals {
  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      butane_version = var.butane_version
      user_name      = var.user.name
      cni_bin_path   = var.cni_bin_path
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.butane_version
      passwd = {
        users = [
          var.user,
        ]
      }
    })
  ])
}