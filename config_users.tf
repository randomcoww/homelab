locals {
  users = {
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
}