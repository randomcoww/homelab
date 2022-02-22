output "config" {
  value = local.config_xml
}

output "secret" {
  value = merge([
    for member in local.syncthing_members :
    {
      "cert-${member.pod_name}" = replace(base64encode(chomp(member.cert)), "\n", "")
      "key-${member.pod_name}"  = replace(base64encode(chomp(member.key)), "\n", "")
    }
  ]...)
}