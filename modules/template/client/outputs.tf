locals {
  params = {
    users            = var.users
    domains          = var.domains
    udev_steam_input = data.http.udev-60-steam-input.body
    udev_steam_vr    = data.http.udev-60-steam-vr.body
    wireguard_config = var.wireguard_config
    syncthing_config = <<EOF
<configuration>
  %{~for k, v in var.syncthing_directories~}
  <folder id="${k}" label="${k}" path="${v}" type="sendreceive" fsWatcherEnabled="true" fsWatcherDelayS="1" rescanIntervalS="10" autoNormalize="false">
    %{~for h in keys(var.hosts)~}
    <device id="${data.syncthing.syncthing[h].device_id}"></device>
    %{~endfor~}
    <maxConflicts>1</maxConflicts>
    <copyOwnershipFromParent>true</copyOwnershipFromParent>
  </folder>
  %{~endfor~}
  %{~for h in keys(var.hosts)~}
  <device id="${data.syncthing.syncthing[h].device_id}" compression="never" skipIntroductionRemovals="true">
    <address>dynamic</address>
    <autoAcceptFolders>true</autoAcceptFolders>
    <allowedNetwork>${var.networks.lan.network}/${var.networks.lan.cidr}</allowedNetwork>
  </device>
  %{~endfor~}
  <gui enabled="false"/>
  <options>
    <listenAddress>tcp://0.0.0.0:${var.services.syncthing.ports.peer}</listenAddress>
    <globalAnnounceEnabled>false</globalAnnounceEnabled>
    <localAnnounceEnabled>true</localAnnounceEnabled>
    <reconnectionIntervalS>5</reconnectionIntervalS>
    <relaysEnabled>false</relaysEnabled>
    <startBrowser>false</startBrowser>
    <natEnabled>false</natEnabled>
    <urAccepted>-1</urAccepted>
    <autoUpgradeIntervalH>0</autoUpgradeIntervalH>
    <defaultFolderPath></defaultFolderPath>
    <crashReportingEnabled>false</crashReportingEnabled>
  </options>
</configuration>
EOF
  }
}

output "ignition" {
  value = {
    for host, params in var.hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition/*") :
      templatefile(f, merge(local.params, {
        p                     = params
        container_images      = var.container_images
        syncthing_directories = var.syncthing_directories
        syncthing_path        = "/var/lib/syncthing"
        tls_syncthing         = tls_locally_signed_cert.syncthing[host].cert_pem
        tls_syncthing_key     = tls_private_key.syncthing[host].private_key_pem
      }))
    ]
  }
}