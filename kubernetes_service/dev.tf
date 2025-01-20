# cosa

resource "minio_iam_user" "cosa" {
  name          = "cosa"
  force_destroy = true
}

resource "minio_iam_policy" "cosa" {
  name = "cosa"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.data["boot"].arn,
          "${minio_s3_bucket.data["boot"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "cosa" {
  user_name   = minio_iam_user.cosa.id
  policy_name = minio_iam_policy.cosa.id
}

module "coreos-assembler" {
  source  = "./modules/coreos_assembler"
  name    = "cosa-build"
  release = "0.1.1"
  images = {
    coreos_assembler = local.container_images.coreos_assembler
  }
  command = [
    "sh",
    "-c",
    <<-EOF
    set -xe

    cd $HOME
    curl https://dl.min.io/client/mc/release/linux-amd64/mc \
      --create-dirs \
      -o $HOME/mc
    chmod +x $HOME/mc

    BUILD_PATH=$HOME/$VARIANT
    mkdir -p $BUILD_PATH
    cd $BUILD_PATH

    cosa init -V $VARIANT \
      --force https://github.com/randomcoww/fedora-coreos-config-custom.git

    cosa clean
    cosa fetch
    cosa build metal4k
    cosa buildextend-metal
    cosa buildextend-live

    $HOME/mc cp -r -q --no-color \
      $BUILD_PATH/builds/latest/x86_64/fedora-*-live* \
      boot/${minio_s3_bucket.data["boot"].id}/
    EOF
  ]
  extra_envs = [
    {
      name  = "COSA_SUPERMIN_MEMORY"
      value = 4096
    },
    {
      name  = "VARIANT"
      value = "coreos"
    },
    {
      name  = "MC_HOST_boot"
      value = "http://${minio_iam_user.cosa.id}:${minio_iam_user.cosa.secret}@${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"
    },
  ]
}

# code-server

module "code" {
  source  = "./modules/code_server"
  name    = "code"
  release = "0.1.1"
  images = {
    code_server = local.container_images.code_server
  }
  ports = {
    code_server = local.host_ports.code
  }
  user      = local.users.client.name
  uid       = local.users.client.uid
  home_path = "${local.mounts.home_path}/${local.users.client.name}"
  extra_configs = [
    {
      path    = "/etc/ssh/ssh_known_hosts"
      content = "@cert-authority * ${chomp(data.terraform_remote_state.sr.outputs.ssh.ca.public_key_openssh)}"
    },
    {
      path    = "/etc/tmux.conf"
      content = <<-EOF
      set -g history-limit 10000
      set -g mouse on
      set-option -s set-clipboard off
      bind-key -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -sel clip"
      EOF
    },
  ]
  extra_envs = [
    {
      name  = "NVIDIA_VISIBLE_DEVICES"
      value = "all"
    },
    {
      name  = "NVIDIA_DRIVER_CAPABILITIES"
      value = "compute,utility"
    },
    {
      name  = "TZ"
      value = local.timezone
    },
  ]
  extra_volumes = [
    {
      name = "run-podman"
      hostPath = {
        path = "/run/podman"
        type = "Directory"
      }
    },
    {
      name = "run-user"
      hostPath = {
        path = "/run/user/${local.users.client.uid}"
        type = "Directory"
      }
    },
  ]
  extra_volume_mounts = [
    {
      name      = "run-podman"
      mountPath = "/run/podman"
    },
    {
      name      = "run-user"
      mountPath = "/run/user/${local.users.client.uid}"
    },
  ]
  resources = {
    limits = {
      "nvidia.com/gpu" = 1
    }
  }
  security_context = {
    capabilities = {
      add = [
        "AUDIT_WRITE",
      ]
    }
  }
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "kubernetes.io/hostname"
                operator = "In"
                values = [
                  "de-1.local",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  service_hostname          = local.kubernetes_ingress_endpoints.code
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}