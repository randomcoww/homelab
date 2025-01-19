resource "minio_s3_bucket" "steamcmd" {
  bucket        = "steamcmd"
  force_destroy = true
}

resource "minio_iam_user" "steamcmd" {
  name          = "steamcmd"
  force_destroy = true
}

resource "minio_iam_policy" "steamcmd" {
  name = "steamcmd"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.steamcmd.arn,
          "${minio_s3_bucket.steamcmd.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "steamcmd" {
  user_name   = minio_iam_user.steamcmd.id
  policy_name = minio_iam_policy.steamcmd.id
}

module "satisfactory-server" {
  source  = "./modules/steamcmd"
  name    = "satisfactory-server"
  release = "0.1.1"
  images = {
    steamcmd = local.container_images.steamcmd
    s3fs     = local.container_images.s3fs
  }
  command = [
    "bash",
    "-c",
    <<-EOF
    set -xe

    until mountpoint $PERSISTENT_PATH; do
    sleep 1
    done

    steamcmd \
      +force_install_dir $PERSISTENT_PATH \
      +login anonymous \
      +app_update "1690800" \
      -beta "public" validate +quit

    mkdir -p \
      $PERSISTENT_PATH/save \
      $(dirname $HOME/$SAVE_PATH)
    ln -sf \
      $PERSISTENT_PATH/save \
      $HOME/$SAVE_PATH

    exec $PERSISTENT_PATH/FactoryServer.sh \
      -Port="$PORT" \
      -ini:Engine:[/Script/FactoryGame.FGSaveSession]:mNumRotatingAutosaves=5 \
      -ini:Engine:[/Script/Engine.GarbageCollectionSettings]:gc.MaxObjectsInEditor=2162688 \
      -ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:LanServerMaxTickRate=30 \
      -ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:NetServerMaxTickRate=30 \
      -ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:ConnectionTimeout=30 \
      -ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:InitialConnectTimeout=30 \
      -ini:Engine:[ConsoleVariables]:wp.Runtime.EnableServerStreaming=false \
      -ini:Game:[/Script/Engine.GameSession]:ConnectionTimeout=30 \
      -ini:Game:[/Script/Engine.GameSession]:InitialConnectTimeout=30 \
      -ini:Game:[/Script/Engine.GameSession]:MaxPlayers=3 \
      -ini:GameUserSettings:[/Script/Engine.GameSession]:MaxPlayers=3
    EOF
  ]
  tcp_ports = {
    api = 7777
  }
  udp_ports = {
    game = 7777
  }
  extra_envs = [
    {
      name  = "SAVE_PATH"
      value = ".config/Epic/FactoryGame/Saved/SaveGames"
    },
    {
      name  = "PORT"
      value = 7777
    },
  ]
  resources = {
    requests = {
      memory = "12Gi"
    }
  }
  healthcheck = {
    exec = {
      command = [
        "bash",
        "-c",
        <<-EOF
        set -o pipefail

        curl -k -f -s -S -X POST "https://$POD_IP:$PORT/api/v1" \
          -H "Content-Type: application/json" \
          -d '{"function":"HealthCheck","data":{"clientCustomData":""}}' \
          | jq -e '.data.health == "healthy"'
        EOF
      ]
    }
    initialDelaySeconds = 300
  }
  service_hostname        = local.kubernetes_ingress_endpoints.satisfactory_server
  service_ip              = local.services.satisfactory_server.ip
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"
  s3_endpoint             = "http://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  s3_bucket               = minio_s3_bucket.steamcmd.id
  s3_access_key_id        = minio_iam_user.steamcmd.id
  s3_secret_access_key    = minio_iam_user.steamcmd.secret
  s3_mount_extra_args = [
    "compat_dir",
    "use_path_request_style",
    "allow_other",
    "use_cache=/tmp",
  ]
}
