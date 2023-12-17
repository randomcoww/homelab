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
      ]
    }
    client = {
      name = "randomcoww"
      uid  = 10000
      groups = [
        "adm",
        "sudo",
        "systemd-journal",
        "wheel",
      ],
    }
  }

  users = merge(local.base_users, {
    for type, user in local.base_users :
    type => merge(
      user,
      lookup(var.users, type, {}),
    )
  })
}
