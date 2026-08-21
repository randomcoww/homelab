output "ignition_snippet" {
  value = yamlencode({
    variant = "fcos"
    version = var.butane_version
    systemd = {
      units = [
        {
          name    = "bird.service"
          enabled = true
          dropins = [
            {
              name     = "10-dependency.conf"
              contents = <<-EOF
                [Unit]
                PartOf=systemd-networkd.service

                [Service]
                ExecStartPre=
                ExecStartPre=/usr/bin/mkdir -p ${var.bird_path}
                ExecStartPre=/usr/sbin/bird -p

                [Install]
                WantedBy=network-online.target
                EOF
            },
          ]
        },
        {
          name    = "haproxy.service"
          enabled = true
          dropins = [
            {
              name     = "10-config-directory.conf"
              contents = <<-EOF
                [Unit]
                ConditionDirectoryNotEmpty=${var.haproxy_path}

                [Service]
                ExecStartPre=
                ExecStart=
                ExecReload=
                ExecStartPre=/usr/bin/mkdir -p ${var.haproxy_path}
                ExecStartPre=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -f ${var.haproxy_path} -c
                ExecStart=/usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -f ${var.haproxy_path} -p $PIDFILE
                ExecReload=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -f ${var.haproxy_path} -c
                Restart=always
                RestartSec=3
                EOF
            },
          ]
        },
        {
          name    = "keepalived.service"
          enabled = true
          dropins = [
            # Part of networkd:
            # Adds the policy route for WAN back in on networkd restart
            {
              name     = "10-dependency.conf"
              contents = <<-EOF
                [Unit]
                PartOf=systemd-networkd.service
                ConditionDirectoryNotEmpty=${var.keepalived_path}

                [Service]
                EnvironmentFile=
                Environment=KEEPALIVED_OPTIONS="-D -P"
                Restart=always
                RestartSec=3
                EOF
            },
          ]
        },
        {
          name    = "nftables@base.service"
          enabled = true
        },
        {
          name    = "sshd.service"
          enabled = true
        },

        # Backup network boot environment to USB disk
        {
          name     = "generate-backup-boot-device.service"
          enabled  = true
          contents = <<-EOF
            [Unit]
            Wants=network-online.target
            After=network-online.target
            ConditionKernelCommandLine=coreos.live.rootfs_url

            [Service]
            Type=oneshot
            RemainAfterExit=yes
            ExecStart=/usr/bin/systemd-inhibit --what=sleep:shutdown:idle generate-backup-boot-device.sh
            Restart=on-failure
            RestartSec=30

            [Install]
            WantedBy=multi-user.target
            EOF
        },
      ]
    }
    passwd = {
      users = [
        merge(var.user, {
          ssh_authorized_keys = [
            "cert-authority ${chomp(var.ssh_ca.public_key_openssh)}",
          ]
        }),
      ]
    }
    storage = {
      files = concat(values(local.ssh_config_files), [

        # BIRD configs
        {
          path = "/etc/sysctl.d/20-bird.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              net.ipv4.conf.all.ignore_routes_with_linkdown=1
              net.ipv4.fib_multipath_use_neigh=1
              EOF
          }
        },
        {
          path      = "/etc/bird.conf"
          mode      = 420
          overwrite = true
          contents = {
            inline = <<-EOF
router id ${var.bgp_router_id};
protocol device {
}
protocol bfd {
}
protocol kernel {
  merge paths on;
  ipv4 {
    export all;
  };
}

ipv4 table ${var.bird_cache_table.name};
protocol kernel cache_table {
  learn;
  kernel table ${var.bird_cache_table.table_id};
  ipv4 {
    import all;
    export none;
    table ${var.bird_cache_table.name};
  };
}
protocol pipe {
  table master4;
  peer table ${var.bird_cache_table.name};
  export none;
  import filter {
    if source = RTS_BGP then {
      accept;
    }
    reject;
  };
}
%{for host_key, netnum in var.bgp_neighbor_netnums}protocol bgp ${replace(host_key, "-", "_")} {
  debug all;
  local port ${var.bgp_port} as ${var.bgp_as};
  neighbor ${cidrhost(var.bgp_prefix, netnum)} port ${var.bgp_port} internal;
  graceful restart;
  direct;
  bfd {
  };
  ipv4 {
    import all;
    export all;
    add paths rx; # allow propagating multiple routes for apiserver
    table ${var.bird_cache_table.name}; # routes for apiserver and default gateway are populated here
  };
}
%{endfor~}

include "${var.bird_path}/*.conf";
EOF
          }
        },

        # HAproxy
        # Last line is a hack for: https://stackoverflow.com/questions/68350378/unable-to-start-haproxy-2-4-missing-lf-on-last-line
        {
          path      = "/etc/haproxy/haproxy.cfg"
          mode      = 420
          overwrite = true
          contents = {
            inline = <<-EOF
              defaults
                mode tcp
                option dontlognull
                timeout http-request 4s
                timeout queue 1m
                timeout connect 4s
                timeout client 86400s
                timeout server 86400s
                timeout tunnel 86400s
              EOF
          }
        },

        # Keepalived configs
        {
          path      = "/etc/keepalived/keepalived.conf"
          mode      = 420
          overwrite = true
          contents = {
            inline = <<-EOF
              global_defs {
                vrrp_version 3
                nftables keepalived
              }
              include ${var.keepalived_path}/*.conf
              EOF
          }
        },
        {
          path = "/etc/sysctl.d/20-keepalived.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              net.ipv4.ip_forward=1
              net.ipv4.ip_nonlocal_bind=1
              EOF
          }
        },
        {
          path = "/etc/modules-load.d/20-keepalived.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              ip_vs
              EOF
          }
        },

        # Nftables base
        {
          path = "/etc/sysctl.d/20-server.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              net.ipv4.ip_forward=1
              EOF
          }
        },
        {
          path      = "/etc/nftables/base.nft"
          mode      = 420
          overwrite = true
          contents = {
            inline = <<-EOF
              table inet base {
                chain mark-for-accept {
                  meta mark set meta mark | ${var.fw_mark}
                }

                chain base-checks {
                  ct state {established, related} jump mark-for-accept;
                  ct state invalid drop;
                  ct status dnat jump mark-for-accept;
                  ip protocol icmp icmp type { echo-request, echo-reply, time-exceeded, parameter-problem, destination-unreachable } jump mark-for-accept;
                }

                chain input {
                  type filter hook input priority -20; policy accept;
                  jump base-checks;
                  iifname lo jump mark-for-accept;
                  iifname != lo ip daddr 127.0.0.1/8 drop;
                }

                chain input-drop {
                  type filter hook input priority 20; policy drop;
                  tcp dport ssh accept;
                  # BGP
                  tcp dport ${var.bgp_port} accept;
                  # BFD
                  udp dport {3784, 4784} accept;
                  meta mark & ${var.fw_mark} == ${var.fw_mark} accept;
                }

                chain forward {
                  type filter hook forward priority -20; policy accept;
                  jump base-checks;
                }

                chain forward-drop {
                  type filter hook forward priority 20; policy drop;
                  tcp dport domain accept;
                  udp dport domain accept;
                  # BFD
                  udp dport 4784 accept;
                  meta mark & ${var.fw_mark} == ${var.fw_mark} accept;
                }

                chain prerouting {
                  type nat hook prerouting priority dstnat + 20; policy accept;
                }
              }
              ;
              EOF
          }
        },

        # SSHD base
        {
          path = "/etc/ssh/sshd_config.d/90-custom.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              PasswordAuthentication no
              HostKey ${local.ssh_config_files.private_key.path}
              HostCertificate ${local.ssh_config_files.certificate.path}
              AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys.d/ignition
              EOF
          }
        },

        # Backup network boot environment to USB disk
        {
          path = "/usr/local/bin/generate-backup-boot-device.sh"
          mode = 493
          contents = {
            inline = <<-EOF
              #!/bin/bash
              set -xe -o pipefail
              mkdir -p ${var.backup_bind_mount_path}

              cleanup() {
                if mountpoint -q ${var.backup_bind_mount_path}; then
                  sync
                  umount ${var.backup_bind_mount_path}
                fi
                rmdir ${var.backup_bind_mount_path}

                if [ -f ${var.backup_temp_image_path} ]; then
                  sync
                  rm ${var.backup_temp_image_path}
                fi
              }
              trap cleanup EXIT

              image_url=$(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url= | sed -r 's/^coreos.live.rootfs_url=(.*)-rootfs(.*)\.img$/\1-iso\2.iso/')
              if [ -z "$image_url" ]; then
                exit 1
              fi
              disk=$(lsblk -ndo kname /dev/disk/by-id/usb-* | head -1)
              if [ -z "$disk" ]; then
                exit 1
              fi

              # Compare image version
              backup_label=$(blkid /dev/$disk -s LABEL -o value)
              current_label=$(cat /proc/cmdline | awk '{print $1}' | sed -r 's/-live-kernel.*//')
              if [ "$backup_label" != "$current_label" ]; then
                curl -fsSL --remove-on-error $image_url --output ${var.backup_temp_image_path}
                cat /run/ignition.json | coreos-installer iso ignition embed ${var.backup_temp_image_path}

                dd if=${var.backup_temp_image_path} of=/dev/$disk bs=4M
                exit 0
              fi

              # Compare ignition
              bindfs --block-devices-as-files /dev ${var.backup_bind_mount_path}
              backup_ign=$(coreos-installer iso ignition show ${var.backup_bind_mount_path}/$disk | sha256sum | awk '{print $1}')
              current_ign=$(cat /run/ignition.json | sha256sum | awk '{print $1}')
              if [ "$backup_ign" != "$current_ign" ]; then
                cat /run/ignition.json | coreos-installer iso ignition embed ${var.backup_bind_mount_path}/$disk -f
              fi
              EOF
          }
        },
      ])
    }
  })
}