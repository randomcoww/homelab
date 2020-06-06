output "templates" {
  value = {
    for host, params in var.static_pod_logging_hosts :
    host => [
      for template in var.static_pod_logging_templates :
      templatefile(template, {
        hostname         = params.hostname
        services         = var.services
        container_images = var.container_images
        kubelet_path     = "/var/lib/kubelet"
        pod_mount_path   = "/var/lib/kubelet/podconfig"
      })
    ]
  }
}

output "addons" {
  value = {
    loki-lb-service = templatefile(var.addon_templates.loki-lb-service, {
      namespace = "monitoring"
      services  = var.services
    })
  }
}