module "jupyter" {
  source  = "./modules/code_server"
  name    = "jupyter"
  release = "0.1.1"
  images = {
    code_server = local.container_images.jupyter
    litestream  = local.container_images.litestream
    juicefs     = local.container_images.juicefs
  }
  user                      = local.users.client.name
  uid                       = local.users.client.uid
  code_server_extra_configs = []
  code_server_extra_envs = [
    {
      name  = "MC_HOST_m"
      value = "http://${data.terraform_remote_state.sr.outputs.minio.access_key_id}:${data.terraform_remote_state.sr.outputs.minio.secret_access_key}@${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"
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

  jfs_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_bucket            = local.minio_buckets.juicefs.name
  jfs_minio_endpoint          = "${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"

  service_hostname          = local.kubernetes_ingress_endpoints.jupyter
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}

module "code" {
  source  = "./modules/code_server"
  name    = "code"
  release = "0.1.1"
  images = {
    code_server = local.container_images.code
    litestream  = local.container_images.litestream
    juicefs     = local.container_images.juicefs
  }
  user = local.users.client.name
  uid  = local.users.client.uid
  code_server_extra_configs = [
    {
      path    = "/etc/containers/containers.conf.d/10-override.conf"
      content = <<-EOF
      [containers]
      userns = "host"
      ipcns = "host"
      cgroupns = "host"
      cgroups = "disabled"
      log_driver = "k8s-file"
      volumes = [
        "/proc:/proc",
      ]
      default_sysctls = []

      [engine]
      cgroup_manager = "cgroupfs"
      events_logger = "none"
      runtime = "crun"
      EOF
    },
    {
      path    = "/etc/containers/storage.conf"
      content = <<-EOF
      [storage]
      driver = "overlay"
      runroot = "/run/containers/storage"
      graphroot = "/var/lib/containers/storage"
      rootless_storage_path = "/tmp/containers-user-$UID/storage"

      [storage.options]
      additionalimagestores = []
      pull_options = {enable_partial_images = "true", use_hard_links = "false", ostree_repos = ""}

      [storage.options.overlay]
      ignore_chown_errors = "true"
      mountopt = "nodev,fsync=0"
      EOF
    },
    {
      path    = "/etc/ssh/ssh_known_hosts"
      content = <<-EOF
      @cert-authority * ${data.terraform_remote_state.sr.outputs.ssh.ca.public_key_openssh}
      EOF
    },
  ]
  code_server_extra_envs = [
    {
      name  = "MC_HOST_m"
      value = "http://${data.terraform_remote_state.sr.outputs.minio.access_key_id}:${data.terraform_remote_state.sr.outputs.minio.secret_access_key}@${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"
    },
  ]
  code_server_resources = {
    limits = {
      "github.com/fuse" = 1
    }
  }
  code_server_security_context = {
    capabilities = {
      add = [
        "AUDIT_WRITE",
      ]
    }
  }

  jfs_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_bucket            = local.minio_buckets.juicefs.name
  jfs_minio_endpoint          = "${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"

  service_hostname          = local.kubernetes_ingress_endpoints.code
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}
