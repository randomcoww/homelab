locals {
  params = {
    container_images   = var.container_images
    services           = var.services
    domains            = var.domains
    kubelet_path       = "/var/lib/kubelet"
    pod_mount_path     = "/var/lib/kubelet/podconfig"
    matchbox_tls_path  = "/etc/matchbox/certs"
    matchbox_data_path = "/etc/matchbox/data"
    syncthing_tls_path = "/var/lib/syncthing"
    vrrp_id            = 50
    dns_redirect_port  = 55353
    kea_path           = "/var/lib/kea"
    kea_hooks_path     = "/usr/local/lib/kea/hooks"
    kea_ha_peers = jsonencode([
      for k, v in var.hosts :
      {
        name          = v.hostname
        role          = lookup(v, "kea_ha_role", "backup")
        url           = "http://${v.networks_by_key.internal.ip}:${var.services.kea.ports.peer}/"
        auto-failover = true
      }
    ])
    syncthing_folder_devices = <<EOF
%{~for host in keys(var.hosts)~}
<device id="${data.syncthing.syncthing[host].device_id}"></device>
%{~endfor~}
EOF
    syncthing_devices        = <<EOF
%{~for host, params in var.hosts~}
<device id="${data.syncthing.syncthing[host].device_id}" compression="never" skipIntroductionRemovals="true">
  <address>${params.networks_by_key.internal.ip}:${var.services.ipxe.ports.sync}</address>
  <autoAcceptFolders>true</autoAcceptFolders>
  <allowedNetwork>${params.networks_by_key.internal.network}/${params.networks_by_key.internal.cidr}</allowedNetwork>
</device>
%{~endfor~}
EOF
  }
}

output "ignition" {
  value = {
    for host, params in var.hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition/*") :
      templatefile(f, merge(local.params, {
        p                 = params
        tls_matchbox_ca   = tls_self_signed_cert.matchbox-ca.cert_pem
        tls_matchbox      = tls_locally_signed_cert.matchbox[host].cert_pem
        tls_matchbox_key  = tls_private_key.matchbox[host].private_key_pem
        tls_syncthing_ca  = tls_self_signed_cert.syncthing-ca.cert_pem
        tls_syncthing     = tls_locally_signed_cert.syncthing[host].cert_pem
        tls_syncthing_key = tls_private_key.syncthing[host].private_key_pem
      }))
    ]
  }
}

output "kubernetes" {
  value = [
    for f in fileset(".", "${path.module}/templates/kubernetes/*") :
    templatefile(f, local.params)
  ]
}

output "matchbox_rpc_endpoint" {
  value = {
    endpoint        = "${var.services.ipxe.vip}:${var.services.ipxe.ports.rpc}"
    cert_pem        = tls_locally_signed_cert.matchbox-client.cert_pem
    private_key_pem = tls_private_key.matchbox-client.private_key_pem
    ca_pem          = tls_self_signed_cert.matchbox-ca.cert_pem
  }
}