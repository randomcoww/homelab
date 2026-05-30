output "trigger" {
  value = {
    for host_key, _ in local.hosts :
    host_key => {
      ignition = sha256(data.terraform_remote_state.host.outputs.ignition[host_key])
      ipxe     = sha256(local.ipxe_configs[host_key])
    }
  }
}

# lldap admin

output "lldap" {
  value = {
    dn   = random_password.lldap-user.result
    pass = random_password.lldap-password.result
  }
  sensitive = true
}

# llama.cpp auth token

output "llama-cpp" {
  value = {
    api_key = random_password.llama-cpp-auth-token.result
  }
  sensitive = true
}