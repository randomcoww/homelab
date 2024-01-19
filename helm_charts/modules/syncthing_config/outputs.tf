output "config" {
  value = templatefile("${path.module}/templates/config.xml", {
    syncthing_members   = local.syncthing_members
    syncthing_home_path = var.syncthing_home_path
    syncthing_peer_port = var.ports.syncthing_peer
    sync_data_paths = [
      for path in var.sync_data_paths :
      {
        path  = path
        label = join("-", compact(split("/", replace(path, "-", "\\x2d"))))
      }
    ]
  })
}

output "peers" {
  value = [
    for member in local.syncthing_members :
    {
      hostname = member.hostname
      cert     = member.cert
      key      = member.key
    }
  ]
}