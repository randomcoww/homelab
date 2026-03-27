output "trigger" {
  value = {
    for host_key, _ in local.hosts :
    host_key => {
      ignition = sha256(data.terraform_remote_state.host.outputs.ignition[host_key])
      ipxe     = sha256(local.ipxe_configs[host_key])
    }
  }
}