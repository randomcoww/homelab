locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      ca_cert            = var.ca.cert_pem
      ca_key             = var.ca.private_key_pem
      nftables_namespace = "sunshine"
      sunshine = {
        config = {
          key_rightalt_to_key_win = "enabled"
          origin_web_ui_allowed   = "pc"
          origin_pin_allowed      = "pc"
          upnp                    = "off"
          cert                    = "/etc/sunshine/credentials/cacert.pem"
          pkey                    = "/etc/sunshine/credentials/cakey.pem"
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