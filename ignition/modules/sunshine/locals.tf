locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version = var.ignition_version
      sunshine = {
        config = merge(var.sunshine_config, {
          upnp      = "off"
          log_path  = "/dev/null"
          file_apps = "/etc/sunshine/apps.json"
        })
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
      external_interface_name = var.external_interface_name
    })
  ]
}