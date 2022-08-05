output "config" {
  value = [
    for i, config in local.configs :
    {
      service_ip        = element(var.service_ips, i)
      pod_name          = element(local.peers, i).name
      ctrl_agent_config = jsonencode(config.ctrl_agent_config)
      dhcp4_config      = jsonencode(config.dhcp4_config)
    }
  ]
}
