## lldap admin

output "lldap" {
  value = {
    dn   = random_password.lldap-user.result
    pass = random_password.lldap-password.result
  }
  sensitive = true
}

output "llama-cpp" {
  value = {
    api_key = random_password.llama-cpp-auth-token.result
  }
  sensitive = true
}