output "ignition_snippet" {
  value = yamlencode({
    variant = "fcos"
    version = var.butane_version
    storage = {
      files = [
        {
          path = "/etc/systemd/resolved.conf.d/10-upstream-dns.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Resolve]
              DNSOverTLS=true
              DNS=${join(" ", [
            for _, d in var.upstream_dns :
            "${d.ip}#${d.hostname}"
      ])}
              EOF
    }
    },
  ]
}
})
}