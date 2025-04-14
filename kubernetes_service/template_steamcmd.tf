resource "minio_s3_bucket" "satisfactory-server" {
  bucket        = "satisfactory-server"
  force_destroy = true
}

resource "minio_iam_user" "satisfactory-server" {
  name          = "satisfactory-server"
  force_destroy = true
}

resource "minio_iam_policy" "satisfactory-server" {
  name = "satisfactory-server"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.satisfactory-server.arn,
          "${minio_s3_bucket.satisfactory-server.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "satisfactory-server" {
  user_name   = minio_iam_user.satisfactory-server.id
  policy_name = minio_iam_policy.satisfactory-server.id
}

module "satisfactory-server" {
  source  = "./modules/steamcmd"
  name    = "satisfactory-server"
  release = "0.1.1"
  images = {
    steamcmd   = local.container_images.steamcmd
    mountpoint = local.container_images.mountpoint
  }
  command = [
    "bash",
    "-c",
    <<-EOF
    set -xe

    until mountpoint $PERSISTENT_PATH; do
    sleep 1
    done

    mkdir -p $PERSISTENT_PATH/save $(dirname $SAVE_PATH)
    ln -sf $PERSISTENT_PATH/save $SAVE_PATH

    exec $STEAMAPP_PATH/FactoryServer.sh \
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
  steamapp_id        = 1690800
  storage_class_name = "local-path"
  tcp_ports = {
    api = 7777
  }
  udp_ports = {
    game = 7777
  }
  extra_envs = [
    {
      name  = "SAVE_PATH"
      value = "$(HOME)/.config/Epic/FactoryGame/Saved/SaveGames"
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
    timeoutSeconds      = 10
    periodSeconds       = 30
    initialDelaySeconds = 30
    failureThreshold    = 4
  }
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"
  s3_endpoint             = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  s3_bucket               = minio_s3_bucket.satisfactory-server.id
  s3_access_key_id        = minio_iam_user.satisfactory-server.id
  s3_secret_access_key    = minio_iam_user.satisfactory-server.secret
  s3_mount_extra_args = [
    "--cache /tmp",
  ]
}
