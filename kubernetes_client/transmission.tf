module "transmission" {
  source  = "./modules/transmission"
  name    = "transmission"
  release = "0.1.6"
  images = {
    transmission = local.container_images.transmission
    wireguard    = local.container_images.wireguard
    jfs          = local.container_images.jfs
    litestream   = local.container_images.litestream
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

  [Peer]
  AllowedIPs=0.0.0.0/0
  Endpoint=${var.wireguard_client.endpoint}
  PublicKey=${var.wireguard_client.public_key}
  PersistentKeepalive=25
  EOF

  service_hostname          = local.kubernetes_ingress_endpoints.transmission
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations

  jfs_minio_access_key_id            = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key        = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_bucket_endpoint          = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}/${local.minio_buckets.jfs.name}"
  litestream_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  litestream_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  litestream_minio_bucket_endpoint   = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}/${local.minio_buckets.litestream.name}"
}