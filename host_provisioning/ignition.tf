locals {
  fw_marks = {
    accept = "0x00002000"
  }
  keepalived_config_path = "/etc/keepalived/keepalived.conf.d"
  haproxy_config_path    = "/etc/haproxy/haproxy.cfg.d"
  bird_config_path       = "/etc/bird.conf.d"
  bird_cache_table = {
    name     = "cache"
    table_id = 240
  }

  users = [
    {
      name     = "fcos"
      home_dir = "/var/home/fcos"
      groups = [
        "adm",
        "sudo",
        "systemd-journal",
        "wheel",
      ],
    },
    {
      name     = "agent"
      home_dir = "/var/home/agent"
      groups = [
        "adm",
        "systemd-journal",
      ],
    },
  ]

  ignition_snippets = {
    for key in keys(local.hosts) :
    key => {
      for component, m in {
        base              = module.base
        systemd-networkd  = module.systemd-networkd
        upstream-dns      = module.upstream-dns
        gateway           = module.gateway
        disks             = module.disks
        etcd              = module.etcd
        kubernetes-master = module.kubernetes-master
        kubernetes-worker = module.kubernetes-worker
        server            = module.server
      } :
      component => m[key].ignition_snippet if contains(keys(m), key)
    }
  }
}

/*
resource "local_file" "ignition-snippets" {
  for_each = nonsensitive(merge([
    for key, ignition_set in local.ignition_snippets : {
      for component, ignition in ignition_set :
      "${key}/${component}.yaml" => ignition
    }
  ]...))

  content  = each.value
  filename = "${path.module}/output/ignition/${each.key}"
}
*/

# outputs

output "ignition_snippets" {
  value = {
    for key, ignition_set in local.ignition_snippets :
    key => values(ignition_set)
  }
  sensitive = true
}