output "trigger" {
  value = {
    for host_key, host in local.hosts :
    host_key => {
      ignition = sha256(local.ignition_configs[host.match_macs[0]])
      ipxe     = sha256(local.ipxe_configs[host.match_macs[0]])
    }
  }
}