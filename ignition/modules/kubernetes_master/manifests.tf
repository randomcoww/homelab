locals {
  config_path               = "${var.config_base_path}/${var.name}"
  apiserver_health_endpoint = "/livez"

  pki = {
    for key, f in {
      kubernetes-ca-cert = {
        contents = var.kubernetes_ca.cert_pem
      }
      kubernetes-ca-key = {
        contents = var.kubernetes_ca.private_key_pem
      }
      apiserver-cert = {
        contents = tls_locally_signed_cert.kube-apiserver.cert_pem
      }
      apiserver-key = {
        contents = tls_private_key.kube-apiserver.private_key_pem
      }
      kubelet-client-cert = {
        contents = tls_locally_signed_cert.kube-apiserver-kubelet-client.cert_pem
      }
      kubelet-client-key = {
        contents = tls_private_key.kube-apiserver-kubelet-client.private_key_pem
      }
      front-proxy-client-ca-cert = {
        contents = var.front_proxy_ca.cert_pem
      }
      front-proxy-client-cert = {
        contents = tls_locally_signed_cert.front-proxy-client.cert_pem
      }
      front-proxy-client-key = {
        contents = tls_private_key.front-proxy-client.private_key_pem
      }
      etcd-ca-cert = {
        contents = var.etcd_ca.cert_pem
      }
      etcd-client-cert = {
        contents = tls_locally_signed_cert.kube-apiserver-etcd-client.cert_pem
      }
      etcd-client-key = {
        contents = tls_private_key.kube-apiserver-etcd-client.private_key_pem
      }
      service-account-cert = {
        contents = var.service_account.public_key_pem
      }
      service-account-key = {
        contents = var.service_account.private_key_pem
      }
    } :
    key => merge(f, {
      path = "${local.config_path}/${key}.pem"
    })
  }

  kubeconfig = {
    for key, f in {
      controller-manager = {
        contents = module.controller-manager-kubeconfig.manifest
      }
      scheduler = {
        contents = module.scheduler-kubeconfig.manifest
      }
    } :
    key => merge(f, {
      path = "${local.config_path}/${key}.kubeconfig"
    })
  }

  config = {
    for key, f in {
      scheduler = {
        contents = yamlencode({
          kind       = "KubeSchedulerConfiguration"
          apiVersion = "kubescheduler.config.k8s.io/v1"
          clientConnection = {
            kubeconfig = local.kubeconfig.scheduler.path
          }
          leaderElection = {
            leaderElect = true
          }
        })
      }
    } :
    key => merge(f, {
      path = "${local.config_path}/${key}.config"
    })
  }

  static_pod = {
    for key, f in {
      apiserver = {
        contents = module.apiserver.manifest
      }
      controller-manager = {
        contents = module.controller-manager.manifest
      }
      scheduler = {
        contents = module.scheduler.manifest
      }
    } :
    key => merge(f, {
      path = "${var.static_pod_path}/${key}.yaml"
    })
  }

  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version = var.ignition_version
      fw_mark          = var.fw_mark
      name             = var.name
      ports            = var.ports
      backend_servers = {
        for host_key, ip in var.members :
        "${host_key}" => "${ip}:${var.ports.apiserver_backend}"
      }
      apiserver_ip              = var.apiserver_ip
      apiserver_health_endpoint = local.apiserver_health_endpoint
      haproxy_path              = var.haproxy_path
      bird_path                 = var.bird_path
      bird_cache_table_name     = var.bird_cache_table_name
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.ignition_version
      storage = {
        files = [
          for _, f in concat(
            values(local.pki),
            values(local.kubeconfig),
            values(local.config),
            values(local.static_pod),
          ) :
          merge({
            mode = 384
            }, f, {
            contents = {
              inline = f.contents
            }
          })
        ]
      }
    }),
  ])

  pod_manifests = [
    for pod in local.static_pod :
    pod.contents
  ]
}

module "controller-manager-kubeconfig" {
  source             = "../../../modules/kubeconfig"
  cluster_name       = var.cluster_name
  user               = var.controller_manager_user
  apiserver_endpoint = "https://127.0.0.1:${var.ports.apiserver}"
  ca_cert_pem        = var.kubernetes_ca.cert_pem
  client_cert_pem    = tls_locally_signed_cert.controller-manager.cert_pem
  client_key_pem     = tls_private_key.controller-manager.private_key_pem
}

module "scheduler-kubeconfig" {
  source             = "../../../modules/kubeconfig"
  cluster_name       = var.cluster_name
  user               = var.scheduler_user
  apiserver_endpoint = "https://127.0.0.1:${var.ports.apiserver}"
  ca_cert_pem        = var.kubernetes_ca.cert_pem
  client_cert_pem    = tls_locally_signed_cert.scheduler.cert_pem
  client_key_pem     = tls_private_key.scheduler.private_key_pem
}

module "apiserver" {
  source    = "../../../modules/static_pod"
  name      = var.name
  namespace = var.namespace
  spec = {
    hostAliases = [
      {
        hostnames = [
          split(".", var.cluster_apiserver_endpoint)[0],
        ]
        ip = "127.0.0.1"
      },
    ]
    containers = [
      {
        name  = "kube-apiserver"
        image = var.images.apiserver
        command = [
          "kube-apiserver",
          "--advertise-address=$(POD_IP)",
          "--allow-privileged=true",
          "--authorization-mode=Node,RBAC",
          "--bind-address=0.0.0.0",
          "--client-ca-file=${local.pki.kubernetes-ca-cert.path}",
          "--etcd-cafile=${local.pki.etcd-ca-cert.path}",
          "--etcd-certfile=${local.pki.etcd-client-cert.path}",
          "--etcd-keyfile=${local.pki.etcd-client-key.path}",
          "--etcd-servers=${join(",", [
            for _, ip in var.etcd_members :
            "https://${ip}:${var.ports.etcd_client}"
          ])}",
          "--event-ttl=1h",
          ## If not running kubelet on the same node
          # "--enable-aggregator-routing=true",
          "--requestheader-allowed-names=${var.front_proxy_client_user}",
          "--requestheader-extra-headers-prefix=X-Remote-Extra-",
          "--requestheader-group-headers=X-Remote-Group",
          "--requestheader-username-headers=X-Remote-User",
          "--requestheader-client-ca-file=${local.pki.front-proxy-client-ca-cert.path}",
          "--proxy-client-cert-file=${local.pki.front-proxy-client-cert.path}",
          "--proxy-client-key-file=${local.pki.front-proxy-client-key.path}",
          "--kubelet-certificate-authority=${local.pki.kubernetes-ca-cert.path}",
          "--kubelet-client-certificate=${local.pki.kubelet-client-cert.path}",
          "--kubelet-client-key=${local.pki.kubelet-client-key.path}",
          "--kubelet-preferred-address-types=InternalDNS,InternalIP",
          "--runtime-config=api/all=true",
          "--secure-port=${var.ports.apiserver_backend}",
          "--service-account-issuer=https://${var.cluster_apiserver_endpoint}",
          "--service-account-key-file=${local.pki.service-account-cert.path}",
          "--service-account-signing-key-file=${local.pki.service-account-key.path}",
          "--service-cluster-ip-range=${var.kubernetes_service_prefix}",
          "--tls-cert-file=${local.pki.apiserver-cert.path}",
          "--tls-private-key-file=${local.pki.apiserver-key.path}",
          "--v=2",
        ]
        env = [
          {
            name = "POD_IP"
            valueFrom = {
              fieldRef = {
                fieldPath = "status.podIP"
              }
            }
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.apiserver_backend
            path   = local.apiserver_health_endpoint
          }
          initialDelaySeconds = 15
          timeoutSeconds      = 15
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.apiserver_backend
            path   = "/readyz"
          }
          initialDelaySeconds = 15
          timeoutSeconds      = 15
        }
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
            readOnly  = true
          },
        ]
      },
    ]
    volumes = [
      {
        name = "config"
        hostPath = {
          path = local.config_path
        }
      },
    ]
  }
}

module "controller-manager" {
  source    = "../../../modules/static_pod"
  name      = "kube-contoller-manager"
  namespace = var.namespace
  spec = {
    containers = [
      {
        name  = "kube-controller-manager"
        image = var.images.controller_manager
        command = [
          "kube-controller-manager",
          "--allocate-node-cidrs=true",
          "--bind-address=127.0.0.1",
          "--cluster-cidr=${var.kubernetes_pod_prefix}",
          "--cluster-name=${var.cluster_name}",
          "--cluster-signing-cert-file=${local.pki.kubernetes-ca-cert.path}",
          "--cluster-signing-key-file=${local.pki.kubernetes-ca-key.path}",
          "--kubeconfig=${local.kubeconfig.controller-manager.path}",
          "--leader-elect=true",
          "--root-ca-file=${local.pki.kubernetes-ca-cert.path}",
          "--service-account-private-key-file=${local.pki.service-account-key.path}",
          "--service-cluster-ip-range=${var.kubernetes_service_prefix}",
          "--use-service-account-credentials=true",
          "--secure-port=${var.ports.controller_manager}",
          "--terminated-pod-gc-threshold=1",
          "--feature-gates=NodeOutOfServiceVolumeDetach=true",
          "--v=2",
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.controller_manager
            path   = "/healthz"
          }
          initialDelaySeconds = 15
          timeoutSeconds      = 15
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.controller_manager
            path   = "/healthz"
          }
          initialDelaySeconds = 15
          timeoutSeconds      = 15
        }
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
            readOnly  = true
          },
        ]
      },
    ]
    volumes = [
      {
        name = "config"
        hostPath = {
          path = local.config_path
        }
      },
    ]
  }
}

module "scheduler" {
  source    = "../../../modules/static_pod"
  name      = "kube-scheduler"
  namespace = var.namespace
  spec = {
    containers = [
      {
        name  = "kube-scheduler"
        image = var.images.scheduler
        command = [
          "kube-scheduler",
          "--config=${local.config.scheduler.path}",
          "--secure-port=${var.ports.scheduler}",
          "--bind-address=127.0.0.1",
          "--v=2",
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.scheduler
            path   = "/healthz"
          }
          initialDelaySeconds = 15
          timeoutSeconds      = 15
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.scheduler
            path   = "/healthz"
          }
          initialDelaySeconds = 15
          timeoutSeconds      = 15
        }
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
            readOnly  = true
          },
        ]
      },
    ]
    volumes = [
      {
        name = "config"
        hostPath = {
          path = local.config_path
        }
      },
    ]
  }
}