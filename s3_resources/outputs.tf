# lldap admin

output "lldap" {
  value = {
    dn   = random_password.lldap-user.result
    pass = random_password.lldap-password.result
  }
  sensitive = true
}

# LLM endpoint

output "llama-cpp" {
  value = {
    base_url = "https://${local.endpoints.llama_cpp.ingress}/v1"
    api_key  = random_password.llama-cpp-auth-token.result
  }
  sensitive = true
}

output "hermes-agent" {
  value = {
    base_url = "https://${local.endpoints.hermes_agent.ingress}/v1"
    api_key  = random_password.hermes-agent-auth-token.result
  }
  sensitive = true
}