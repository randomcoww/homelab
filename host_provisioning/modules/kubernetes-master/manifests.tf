locals {
  config_path = "${var.config_base_path}/${var.name}"

  kubeconfig_files = {
    for key, f in {
      "controller-manager.kubeconfig" = module.controller-manager-kubeconfig.manifest
      "scheduler.kubeconfig"          = module.scheduler-kubeconfig.manifest
    } :
    key => {
      mode = 384
      path = "${local.config_path}/${key}"
      contents = {
        inline = f
      }
    }
  }

  config_files = {
    for key, f in {
      "scheduler.config" = yamlencode({
        kind       = "KubeSchedulerConfiguration"
        apiVersion = "kubescheduler.config.k8s.io/v1"
        clientConnection = {
          kubeconfig = local.kubeconfig_files["scheduler.kubeconfig"].path
        }
        leaderElection = {
          leaderElect = true
        }
      })
      "apiserver-encryption.config" = yamlencode({
        apiVersion = "apiserver.config.k8s.io/v1"
        kind       = "EncryptionConfiguration"
        resources = [
          {
            resources = [
              "secrets",
              "configmaps",
            ]
            providers = [
              {
                aescbc = {
                  keys = [
                    {
                      name   = "key1"
                      secret = var.apiserver_encryption_key
                    },
                  ]
                }
              },
              {
                identity = {}
              },
            ]
          },
        ]
      })
    } :
    key => {
      mode = 384
      path = "${local.config_path}/${key}"
      contents = {
        inline = f
      }
    }
  }

  pki_files = {
    for key, f in {
      "kubernetes-ca.crt"         = var.kubernetes_ca.cert_pem
      "kubernetes-ca.key"         = var.kubernetes_ca.private_key_pem
      "apiserver.crt"             = tls_locally_signed_cert.kube-apiserver.cert_pem
      "apiserver.key"             = tls_private_key.kube-apiserver.private_key_pem
      "kubelet-client.crt"        = tls_locally_signed_cert.kube-apiserver-kubelet-client.cert_pem
      "kubelet-client.key"        = tls_private_key.kube-apiserver-kubelet-client.private_key_pem
      "front-proxy-client-ca.crt" = var.front_proxy_ca.cert_pem
      "front-proxy-client.crt"    = tls_locally_signed_cert.front-proxy-client.cert_pem
      "front-proxy-client.key"    = tls_private_key.front-proxy-client.private_key_pem
      "etcd-ca.crt"               = var.etcd_ca.cert_pem
      "etcd-client.crt"           = tls_locally_signed_cert.kube-apiserver-etcd-client.cert_pem
      "etcd-client.key"           = tls_private_key.kube-apiserver-etcd-client.private_key_pem
      "service-account.crt"       = var.service_account.public_key_pem
      "service-account.key"       = var.service_account.private_key_pem
    } :
    key => {
      mode = 384
      path = "${local.config_path}/${key}"
      contents = {
        inline = f
      }
    }
  }
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
  source = "../../../modules/static-pod"
  name   = var.apiserver_label
  spec = {
    # kube-vip with local kube-proxy
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
        image = "${var.images.apiserver.repository}:${var.images.apiserver.tag}"
        command = compact(concat([
          "kube-apiserver",
          "--advertise-address=$(POD_IP)",
          "--allow-privileged=true",
          "--authorization-mode=Node,RBAC",
          "--bind-address=0.0.0.0",
          "--secure-port=${var.ports.apiserver_backend}",
          "--client-ca-file=${local.pki_files["kubernetes-ca.crt"].path}",
          "--etcd-cafile=${local.pki_files["etcd-ca.crt"].path}",
          "--etcd-certfile=${local.pki_files["etcd-client.crt"].path}",
          "--etcd-keyfile=${local.pki_files["etcd-client.key"].path}",
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
          "--requestheader-client-ca-file=${local.pki_files["front-proxy-client-ca.crt"].path}",
          "--proxy-client-cert-file=${local.pki_files["front-proxy-client.crt"].path}",
          "--proxy-client-key-file=${local.pki_files["front-proxy-client.key"].path}",
          "--kubelet-certificate-authority=${local.pki_files["kubernetes-ca.crt"].path}",
          "--kubelet-client-certificate=${local.pki_files["kubelet-client.crt"].path}",
          "--kubelet-client-key=${local.pki_files["kubelet-client.key"].path}",
          "--kubelet-preferred-address-types=InternalDNS,InternalIP",
          "--runtime-config=api/all=true",
          "--service-account-issuer=https://${var.cluster_apiserver_endpoint}",
          "--service-account-key-file=${local.pki_files["service-account.crt"].path}",
          "--service-account-signing-key-file=${local.pki_files["service-account.key"].path}",
          "--service-cluster-ip-range=${var.kubernetes_service_prefix}",
          "--tls-cert-file=${local.pki_files["apiserver.crt"].path}",
          "--tls-private-key-file=${local.pki_files["apiserver.key"].path}",
          "--encryption-provider-config=${local.config_files["apiserver-encryption.config"].path}",
          "--v=2",
          ], length(var.feature_gates) > 0 ? [
          "--feature-gates=${join(",", [
            for k, v in var.feature_gates :
            "${k}=${tostring(v)}"
          ])}",
        ] : []))
        resources = {
          requests = {
            memory = "3Gi"
          }
          limits = {
            memory = "3Gi"
          }
        }
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
            path   = "/livez"
          }
          timeoutSeconds   = 4
          failureThreshold = 6
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.apiserver_backend
            path   = "/readyz"
          }
          timeoutSeconds = 4
        }
        startupProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.apiserver_backend
            path   = "/livez"
          }
          failureThreshold = 6
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
  source = "../../../modules/static-pod"
  name   = "kube-contoller-manager"
  spec = {
    containers = [
      {
        name  = "kube-controller-manager"
        image = "${var.images.controller_manager.repository}:${var.images.controller_manager.tag}"
        command = compact(concat([
          "kube-controller-manager",
          "--allocate-node-cidrs=true",
          "--bind-address=127.0.0.1",
          "--cluster-cidr=${var.kubernetes_pod_prefix}",
          "--cluster-name=${var.cluster_name}",
          "--cluster-signing-cert-file=${local.pki_files["kubernetes-ca.crt"].path}",
          "--cluster-signing-key-file=${local.pki_files["kubernetes-ca.key"].path}",
          "--kubeconfig=${local.kubeconfig_files["controller-manager.kubeconfig"].path}",
          "--leader-elect=true",
          "--root-ca-file=${local.pki_files["kubernetes-ca.crt"].path}",
          "--service-account-private-key-file=${local.pki_files["service-account.key"].path}",
          "--service-cluster-ip-range=${var.kubernetes_service_prefix}",
          "--use-service-account-credentials=true",
          "--secure-port=${var.ports.controller_manager}",
          "--terminated-pod-gc-threshold=1",
          "--v=2",
          ], length(var.feature_gates) > 0 ? [
          "--feature-gates=${join(",", [
            for k, v in var.feature_gates :
            "${k}=${tostring(v)}"
          ])}",
        ] : []))
        resources = {
          requests = {
            memory = "512Mi"
          }
          limits = {
            memory = "512Mi"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.controller_manager
            path   = "/healthz"
          }
          timeoutSeconds   = 4
          failureThreshold = 6
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.controller_manager
            path   = "/healthz"
          }
          timeoutSeconds = 4
        }
        startupProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.controller_manager
            path   = "/healthz"
          }
          failureThreshold = 6
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
  source = "../../../modules/static-pod"
  name   = "kube-scheduler"
  spec = {
    containers = [
      {
        name  = "kube-scheduler"
        image = "${var.images.scheduler.repository}:${var.images.scheduler.tag}"
        command = compact(concat([
          "kube-scheduler",
          "--config=${local.config_files["scheduler.config"].path}",
          "--secure-port=${var.ports.scheduler}",
          "--bind-address=127.0.0.1",
          "--v=2",
          ], length(var.feature_gates) > 0 ? [
          "--feature-gates=${join(",", [
            for k, v in var.feature_gates :
            "${k}=${tostring(v)}"
          ])}",
        ] : []))
        resources = {
          requests = {
            memory = "256Mi"
          }
          limits = {
            memory = "256Mi"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.scheduler
            path   = "/healthz"
          }
          timeoutSeconds   = 4
          failureThreshold = 6
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.scheduler
            path   = "/healthz"
          }
          timeoutSeconds = 4
        }
        startupProbe = {
          httpGet = {
            scheme = "HTTPS"
            host   = "127.0.0.1"
            port   = var.ports.scheduler
            path   = "/healthz"
          }
          failureThreshold = 6
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