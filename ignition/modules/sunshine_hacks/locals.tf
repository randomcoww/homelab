locals {
  udev = [
    # sunshine input rules
    {
      path     = "/etc/udev/rules.d/85-sunshine-uinput.rules"
      contents = <<-EOF
      KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
      EOF
    },
  ]

  ignition_snippets = concat([
    yamlencode({
      variant = "fcos"
      version = var.ignition_version
      storage = {
        files = [
          for _, f in concat(
            local.udev,
          ) :
          merge({
            mode = 384
            }, f, {
            contents = {
              inline = f.contents
            }
          })
        ]
      }
    }),
    ], [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version        = var.ignition_version
      external_interface_name = var.external_interface_name
    })
  ])
}