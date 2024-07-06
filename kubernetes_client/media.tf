module "transmission" {
  source  = "./modules/transmission"
  name    = "transmission"
  release = "0.1.6"
  images = {
    transmission = local.container_images.transmission
    wireguard    = local.container_images.wireguard
    juicefs      = local.container_images.juicefs
  }
  transmission_settings = {
    blocklist-enabled            = true
    blocklist-url                = "http://list.iblocklist.com/?list=ydxerpxkpcfqjaybcssw&fileformat=p2p&archiveformat=gz"
    download-queue-enabled       = true
    encryption                   = 2
    max-peers-global             = 1000
    port-forwarding-enabled      = false
    preallocation                = 0
    queue-stalled-enabled        = true
    ratio-limit                  = 0
    ratio-limit-enabled          = true
    rename-partial-files         = true
    rpc-authentication-required  = false
    rpc-host-whitelist-enabled   = false
    rpc-url                      = "/transmission/"
    rpc-whitelist-enabled        = false
    script-torrent-done-enabled  = true
    speed-limit-down-enabled     = false
    speed-limit-up-enabled       = true
    start-added-torrents         = true
    trash-original-torrent-files = true
    incomplete-dir-enabled       = false
  }
  transmission_extra_envs = [
    {
      name  = "MC_HOST_m"
      value = "http://${data.terraform_remote_state.sr.outputs.minio.access_key_id}:${data.terraform_remote_state.sr.outputs.minio.secret_access_key}@${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
    },
  ]
  torrent_done_script = <<-EOF
  #!/bin/sh
  set -xe
  #  * TR_APP_VERSION
  #  * TR_TIME_LOCALTIME
  #  * TR_TORRENT_DIR
  #  * TR_TORRENT_HASH
  #  * TR_TORRENT_ID
  #  * TR_TORRENT_NAME
  #  * TR_RPC_PORT (custom)
  cd "$TR_TORRENT_DIR"

  transmission-remote $TR_RPC_PORT \
    --torrent "$TR_TORRENT_ID" \
    --verify

  mcli cp -r -q --no-color \
    "$TR_TORRENT_NAME" \
    "m/${local.minio_buckets.downloads.name}/"

  transmission-remote $TR_RPC_PORT \
    --torrent "$TR_TORRENT_ID" \
    --remove-and-delete
  EOF
  wireguard_config    = <<-EOF
  [Interface]
  Address=${var.wireguard_client.address}
  PrivateKey=${var.wireguard_client.private_key}
  PostUp=nft add table ip filter
  PostUp=nft add chain ip filter output { type filter hook output priority 0 \; }
  PostUp=nft insert rule ip filter output oifname != "%i" mark != $(wg show %i fwmark) fib daddr type != local ip daddr != ${local.networks.kubernetes_service.prefix} ip daddr != ${local.networks.kubernetes_pod.prefix} reject
  PostUp=ip route add ${local.networks.kubernetes_service.prefix} via $(ip -4 route show ${local.networks.kubernetes_pod.prefix} | awk '{print $3}')

  [Peer]
  AllowedIPs=0.0.0.0/0,::0/0
  Endpoint=${var.wireguard_client.endpoint}
  PublicKey=${var.wireguard_client.public_key}
  PersistentKeepalive=25
  EOF

  jfs_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_resource          = "${local.minio_buckets.juicefs.name}/transmission"
  jfs_minio_endpoint          = "${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  jfs_redis_ca = {
    algorithm       = tls_private_key.jfs-redis-ca.algorithm
    private_key_pem = tls_private_key.jfs-redis-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.jfs-redis-ca.cert_pem
  }
  jfs_redis_endpoint = "${local.kubernetes_services.jfs_redis.endpoint}:${local.service_ports.redis}"
  jfs_redis_db_id    = 1

  service_hostname          = local.kubernetes_ingress_endpoints.transmission
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}

# Music stream

module "mpd" {
  source  = "./modules/mpd"
  name    = "mpd"
  release = "0.1.0"
  images = {
    mpd        = local.container_images.mpd
    mympd      = local.container_images.mympd
    rclone     = local.container_images.rclone
    litestream = local.container_images.litestream
    juicefs    = local.container_images.juicefs
  }
  audio_outputs = [
    {
      name = "flac-3"
      config = {
        tags        = "yes"
        format      = "48000:24:2"
        always_on   = "yes"
        encoder     = "flac"
        compression = 3
        max_clients = 2
      }
    },
    {
      name = "lame-9"
      config = {
        tags        = "yes"
        format      = "48000:24:2"
        always_on   = "yes"
        encoder     = "lame"
        quality     = 9
        max_clients = 2
      }
    },
  ]

  jfs_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_resource          = "${local.minio_buckets.juicefs.name}/mpd"
  jfs_minio_endpoint          = "${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  jfs_redis_ca = {
    algorithm       = tls_private_key.jfs-redis-ca.algorithm
    private_key_pem = tls_private_key.jfs-redis-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.jfs-redis-ca.cert_pem
  }
  jfs_redis_endpoint = "${local.kubernetes_services.jfs_redis.endpoint}:${local.service_ports.redis}"
  jfs_redis_db_id    = 2

  data_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  data_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  data_minio_bucket            = local.minio_buckets.music.name
  data_minio_endpoint          = "${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"

  service_hostname          = local.kubernetes_ingress_endpoints.mpd
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}

# Webdav

module "webdav-pictures" {
  source  = "./modules/webdav"
  name    = "webdav-pictures"
  release = "0.1.0"
  images = {
    rclone = local.container_images.rclone
  }

  data_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  data_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  data_minio_bucket            = local.minio_buckets.pictures.name
  data_minio_endpoint          = "${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"

  service_hostname          = local.kubernetes_ingress_endpoints.webdav_pictures
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
}