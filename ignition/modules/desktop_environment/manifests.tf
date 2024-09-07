locals {
  udev = [
    # controller support in steam flatpak
    {
      path     = "/etc/udev/rules.d/62-steam-input.rules"
      contents = data.http.udev-60-steam-input.response_body
      mode     = 420
    },
    {
      path     = "/etc/udev/rules.d/62-steam-vr.rules"
      contents = data.http.udev-60-steam-vr.response_body
      mode     = 420
    },
    # sunshine input rules
    {
      path = "/etc/udev/rules.d/85-sunshine-uinput.rules"
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
    ],
    [
      for f in fileset(".", "${path.module}/templates/*.yaml") :
      templatefile(f, {
        ignition_version = var.ignition_version
      })
  ])
}

data "http" "udev-60-steam-input" {
  url = "https://raw.githubusercontent.com/ValveSoftware/steam-devices/master/60-steam-input.rules"
}

data "http" "udev-60-steam-vr" {
  url = "https://raw.githubusercontent.com/ValveSoftware/steam-devices/master/60-steam-vr.rules"
}