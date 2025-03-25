
module "kube-dns" {
  source    = "./modules/kube_dns"
  name      = "kube-dns"
  namespace = "kube-system"
  helm_template = {
    repository = "https://coredns.github.io/helm"
    chart      = "coredns"
    version    = "1.39.2"
  }
  replicas = 3
  images = {
    etcd         = local.container_images.etcd
    external_dns = local.container_images.external_dns
  }
  ports = {
    metrics = local.service_ports.metrics
  }
  service_cluster_ip      = local.services.cluster_dns.ip
  service_ip              = local.services.external_dns.ip
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"
  servers = [
    {
      zones = [
        {
          zone = "."
        },
      ]
      port = 53
      plugins = [
        {
          name = "health"
        },
        {
          name = "ready"
        },
        {
          name        = "kubernetes"
          parameters  = "${local.domains.kubernetes} in-addr.arpa ip6.arpa"
          configBlock = <<-EOF
          pods insecure
          fallthrough
          EOF
        },
        {
          name        = "etcd"
          parameters  = "${local.domains.public} in-addr.arpa ip6.arpa"
          configBlock = <<-EOF
          fallthrough
          EOF
        },
        # public DNS
        {
          name        = "forward"
          parameters  = ". tls://${local.upstream_dns.ip}"
          configBlock = <<-EOF
          tls_servername ${local.upstream_dns.hostname}
          health_check 5s
          EOF
        },
        {
          name       = "cache"
          parameters = 30
        },
        {
          name       = "prometheus"
          parameters = "0.0.0.0:${local.service_ports.metrics}"
        },
      ]
    },
  ]
}