locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      sunshine = {
        config = {
          key_rightalt_to_key_win = "enabled"
          origin_web_ui_allowed   = "pc"
          upnp                    = "off"
          log_path                = "/dev/null"
          file_apps               = "/etc/sunshine/apps.json"
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