resource "tls_private_key" "kubernetes-admin" {
  algorithm   = data.terraform_remote_state.sr.outputs.kubernetes.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kubernetes-admin" {
  private_key_pem = tls_private_key.kubernetes-admin.private_key_pem

  subject {
    common_name  = "kubernetes-super-admin"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "kubernetes-admin" {
  cert_request_pem   = tls_cert_request.kubernetes-admin.cert_request_pem
  ca_private_key_pem = data.terraform_remote_state.sr.outputs.kubernetes.ca.private_key_pem
  ca_cert_pem        = data.terraform_remote_state.sr.outputs.kubernetes.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

module "admin-kubeconfig" {
  source             = "../modules/kubeconfig"
  cluster_name       = local.kubernetes.cluster_name
  user               = "kubernetes-super-admin"
  apiserver_endpoint = "https://${local.services.cluster_apiserver.ip}:443"
  ca_cert_pem        = data.terraform_remote_state.sr.outputs.kubernetes.ca.cert_pem
  client_cert_pem    = tls_locally_signed_cert.kubernetes-admin.cert_pem
  client_key_pem     = tls_private_key.kubernetes-admin.private_key_pem
}

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
  code_server_extra_configs = [
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
    {
      path    = "/etc/admin-kubeconfig.conf"
      content = module.admin-kubeconfig.manifest
    },
  ]
  code_server_extra_envs = [
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
    {
      name  = "KUBECONFIG"
      value = "/etc/admin-kubeconfig.conf"
    },
  ]
  code_server_extra_volumes = [
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
  code_server_extra_volume_mounts = [
    {
      name      = "run-podman"
      mountPath = "/run/podman"
    },
    {
      name      = "run-user"
      mountPath = "/run/user/${local.users.client.uid}"
    },
  ]
  code_server_resources = {
    limits = {
      "nvidia.com/gpu" = 1
    }
  }
  code_server_security_context = {
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