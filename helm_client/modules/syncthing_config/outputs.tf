output "config" {
  value = local.config_xml
}

output "peers" {
  value = [
    for member in local.syncthing_members :
    {
      pod_name = member.pod_name
      cert     = member.cert
      key      = member.key
    }
  ]
}