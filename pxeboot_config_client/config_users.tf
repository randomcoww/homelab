locals {
  # do not use #
  base_users = {
    admin = {
      name = "fcos"
      groups = [
        "adm",
        "sudo",
        "systemd-journal",
        "wheel",
        "libvirt",
      ]
    }
    client = {
      name     = "randomcoww"
      uid      = 10000
      home_dir = "/var/home/randomcoww"
      groups = [
        "adm",
        "sudo",
        "systemd-journal",
        "wheel",
        "libvirt",
      ]
    }
  }

  # use this instead of base_users #
  users = merge(local.base_users, {
    for user_name, user in local.base_users :
    user_name => merge(user, lookup(var.users, user_name, {}))
  })
}