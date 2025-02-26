locals {
  users = {
    ssh = {
      name     = "fcos"
      home_dir = "/var/tmp-home/fcos"
      groups = [
        "adm",
        "sudo",
        "systemd-journal",
        "wheel",
      ],
    }
    client = {
      name     = "randomcoww"
      home_dir = "/var/home/randomcoww"
      uid      = 10000
      groups = [
        "adm",
        "sudo",
        "systemd-journal",
        "wheel",
      ],
    }
  }
}