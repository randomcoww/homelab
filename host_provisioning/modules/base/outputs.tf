output "ignition_snippet" {
  value = yamlencode({
    variant = "fcos"
    version = var.butane_version
    passwd = {
      users = [
        {
          name         = "core"
          should_exist = false
        },
      ]
    }
    systemd = {
      units = [
        {
          name = "rpm-ostree-countme.service"
          mask = true
        },
        {
          name = "rpm-ostree-countme.timer"
          mask = true
        },
        {
          name    = "chronyd.service"
          enabled = true
        },
        # enable trim on all disks
        {
          name    = "fstrim.service"
          enabled = true
          dropins = [
            {
              name     = "10-all.conf"
              contents = <<-EOF
                [Service]
                ExecStart=
                ExecStart=/usr/sbin/fstrim --all --verbose --quiet
                EOF
            },
          ]
        },
        {
          name = "systemd-network-generator.service"
          mask = true
        },
        {
          name    = "systemd-resolved.service"
          enabled = true
        },
        # configure nftables for each service
        {
          name = "nftables.service"
          mask = false
        },
        # TODO = work around loop with basic.target:
        # Found ordering cycle = sockets.target/start after systemd-networkd-resolve-hook.socket/start after network-pre.target/start after nftables@kube-worker.service/start after basic.target/start - after sockets.target
        # Add DefaultDependencies=no to remove defauts
        # Add everything back except for basic.target
        {
          name     = "nftables@.service"
          enabled  = true
          contents = <<-EOF
            [Unit]
            DefaultDependencies=no
            Wants=network-pre.target
            Before=network-pre.target shutdown.target
            After=sysinit.target systemd-journald.socket system.slice
            Conflicts=shutdown.target
            ConditionFileNotEmpty=/etc/nftables/%i.nft

            [Service]
            Type=oneshot
            ProtectSystem=full
            ProtectHome=true
            ExecStart=/sbin/nft -f /etc/nftables/%i.nft
            ExecReload=/sbin/nft 'delete table inet %i; include "/etc/nftables/%i.nft";'
            ExecStop=/sbin/nft delete table inet %i
            RemainAfterExit=yes

            [Install]
            WantedBy=multi-user.target
            EOF
        },
        {
          name = "zincati.service"
          mask = true
        },
      ]
    }
    storage = {
      files = [
        {
          path = "/etc/hostname"
          mode = 420
          contents = {
            inline = var.hostname
          }
        },
        {
          path      = "/etc/hosts"
          overwrite = true
          mode      = 420
          contents = {
            inline = <<-EOF
              127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4
              ::1       localhost localhost.localdomain localhost6 localhost6.localdomain6
              ${var.hosts_entry}
              EOF
          }
        },
        # Use avahi and disable all resolved mdns
        {
          path = "/etc/systemd/resolved.conf.d/10-base.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Resolve]
              DNSStubListener=false
              MulticastDNS=false
              LLMNR=false
              EOF
          }
        },
        # Block password SSH #
        {
          path = "/etc/ssh/sshd_config.d/10-block-password.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              PasswordAuthentication no
              EOF
          }
        },
        # Systemd for live image #
        {
          path = "/etc/systemd/journald.conf.d/10-live-boot-config.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Journal]
              Storage=volatile
              RuntimeMaxUse=10M
              SystemMaxUse=10M
              SystemMaxFileSize=10M
              ForwardToSyslog=false
              ForwardToConsole=false
              EOF
          }
        },
        {
          path = "/etc/systemd/system.conf.d/10-live-boot-config.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Manager]
              DumpCore=false
              EOF
          }
        },
        # Disable speaker #
        {
          path = "/etc/modprobe.d/10-blacklist-pcspk.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              blacklist pcspkr
              blacklist snd_pcsp
              EOF
          }
        },
        # DNS reply from unexpected source #
        {
          path = "/etc/modules-load.d/20-dns-reply.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              br_netfilter
              EOF
          }
        },
        # common #
        {
          path = "/etc/sysctl.d/10-common.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              kernel.printk=4
              fs.inotify.max_user_watches=524288
              EOF
          }
        },
        # MSS clamping #
        {
          path = "/etc/sysctl.d/10-mss-clamping.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              net.ipv4.tcp_mtu_probing=2
              EOF
          }
        },
        # sudoers #
        {
          path      = "/etc/sudoers.d/coreos-sudo-group"
          overwrite = true
          mode      = 384
          contents = {
            inline = <<-EOF
              %sudo ALL=(ALL) NOPASSWD: ALL
              EOF
          }
        },

        # prevent hibernation
        {
          path = "/etc/systemd/logind.conf.d/10-disable-hibernate"
          mode = 420
          contents = {
            inline = <<-EOF
              [Login]
              HibernateKeyIgnoreInhibited=no
              EOF
          }
        },
        # ignore lid operations for running as server on laptop
        {
          path = "/etc/systemd/logind.conf.d/10-ignore-lid-switch.conf"
          contents = {
            inline = <<-EOF
              [Login]
              HandleLidSwitch=ignore
              HandleLidSwitchExternalPower=ignore
              HandleLidSwitchDocked=ignore
              EOF
          }
        },
        # No swap - disable hibernation
        {
          path = "/etc/systemd/sleep.conf.d/10-disable-hibernate.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Sleep]
              AllowSuspend=no
              AllowHibernation=no
              AllowSuspendThenHibernate=no
              AllowHybridSleep=no
              EOF
          }
        },
      ]
    }
  })
}