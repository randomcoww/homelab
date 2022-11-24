locals {
  # do not use #
  base_users = {
    admin = {
      name = "fcos"
      unix = {
        home_dir = "/var/home/fcos"
        groups = [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel",
        ]
      }
    }
    client = {
      name = "randomcoww"
      unix = {
        uid      = 10000
        home_dir = "/var/home/randomcoww"
        groups = [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel",
        ]
      }
    }
  }

  users = merge(local.base_users, {
    for type, user in local.base_users :
    type => {
      name = user.name
      unix = merge(lookup(user, "unix", {}), lookup(lookup(var.users, type, {}), "unix", {}))
      sso  = merge(lookup(user, "sso", {}), lookup(lookup(var.users, type, {}), "sso", {}))
    }
  })
}