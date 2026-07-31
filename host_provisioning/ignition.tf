locals {
  fw_marks = {
    accept = "0x00002000"
  }
  keepalived_config_path = "/etc/keepalived/keepalived.conf.d"
  haproxy_config_path    = "/etc/haproxy/haproxy.cfg.d"
  bird_config_path       = "/etc/bird.conf.d"
  bird_cache_table_name  = "cache"

  users = {
    ssh = {
      name     = "fcos"
      home_dir = "/var/home/fcos"
      groups = [
        "adm",
        "sudo",
        "systemd-journal",
        "wheel",
      ],
    }
  }
}

# outputs

output "ignition_snippets" {
  value = {
    for host_key in keys(local.hosts) :
    host_key => sort(compact([
      for m in [
        module.base,
        module.systemd-networkd,
        module.upstream-dns,
        module.gateway,
        module.disks,
        module.etcd,
        module.kubernetes-master,
        module.kubernetes-worker,
        module.server,
      ] :
      try(m[host_key].ignition_snippet, null)
    ]))
  }
  sensitive = true
}