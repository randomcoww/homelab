locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      sunshine = {
        config = {
          key_rightalt_to_key_win = "enabled"
          min_log_level           = "error"
          origin_web_ui_allowed   = "pc"
          origin_pin_allowed      = "pc"
          upnp                    = "off"
        }
        apps = {
          env = {
            PATH = "$(PATH):$(HOME)/.local/bin"
          }
          apps = [
            {
              name       = "Desktop"
              image-path = "desktop.png"
            }
          ]
        }
      }
    })
  ]
}