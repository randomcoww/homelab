locals {
  serviceaccount = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name = var.name
      labels = {
        app     = var.name
        release = var.release
      }
    }
  }

  role = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = var.name
      labels = {
        app     = var.name
        release = var.release
      }
      annotations = {
        "rbac.authorization.kubernetes.io/autoupdate" = "true"
      }
    }
    rules = [
      {
        apiGroups = [""]
        resources = ["services/status"]
        verbs     = ["update"]
      },
      {
        apiGroups = [""]
        resources = ["services", "endpoints"]
        verbs     = ["list", "get", "watch", "update"]
      },
      {
        apiGroups = [""]
        resources = ["nodes"]
        verbs     = ["list", "get", "watch", "update", "patch"]
      },
      {
        apiGroups = ["coordination.k8s.io"]
        resources = ["leases"]
        verbs     = ["list", "get", "watch", "update", "create"]
      },
      {
        apiGroups = ["discovery.k8s.io"]
        resources = ["endpointslices"]
        verbs     = ["list", "get", "watch", "update"]
      },
    ]
  }

  rolebinding = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = var.name
      labels = {
        app     = var.name
        release = var.release
      }
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = var.name
    }
    subjects = [
      {
        kind      = "ServiceAccount"
        name      = var.name
        namespace = var.namespace
      },
    ]
  }
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.kube_vip)[1]
  manifests = {
    "templates/serviceaccount.yaml"     = yamlencode(local.serviceaccount)
    "templates/clusterrole.yaml"        = yamlencode(local.role)
    "templates/clusterrolebinding.yaml" = yamlencode(local.rolebinding)
    "templates/daemonset.yaml"          = module.daemonset.manifest
  }
}

module "daemonset" {
  source   = "../../../modules/daemonset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  template_spec = {
    hostNetwork        = true
    priorityClassName  = "system-cluster-critical"
    serviceAccountName = var.name
    tolerations = [
      {
        operator = "Exists"
        effect   = "NoExecute"
      },
      {
        operator = "Exists"
        effect   = "NoSchedule"
      },
    ]
    containers = [
      {
        name  = "kube-vip"
        image = var.images.kube_vip
        args = [
          "manager",
        ]
        env = [
          {
            name  = "vip_arp"
            value = "false"
          },
          {
            name  = "port"
            value = tostring(var.ports.apiserver)
          },
          {
            name  = "vip_interface"
            value = "lo"
          },
          {
            name = "vip_nodename"
            valueFrom = {
              fieldRef = {
                fieldPath = "spec.nodeName"
              }
            }
          },
          {
            name  = "dns_mode"
            value = "first"
          },
          {
            name  = "cp_enable"
            value = "true"
          },
          {
            name  = "svc_enable"
            value = "true"
          },
          {
            name  = "lb_enable"
            value = "false"
          },
          {
            name  = "lb_port"
            value = tostring(var.ports.apiserver)
          },
          {
            name  = "svc_leasename"
            value = "plndr-svcs-lock"
          },
          {
            name  = "vip_routingtable"
            value = "false"
          },
          {
            name  = "bgp_enable"
            value = "true"
          },
          {
            name = "bgp_routerid"
            valueFrom = {
              fieldRef = {
                fieldPath = "status.podIP"
              }
            }
          },
          {
            name  = "bgp_as"
            value = tostring(var.bgp_as)
          },
          {
            name = "bgp_peers"
            value = join(",", [
              for _, ip in var.bgp_neighbor_ips :
              "${ip}:${var.bgp_peeras}::false"
            ])
          },
          {
            name  = "address"
            value = var.apiserver_ip
          },
          {
            name  = "egress_withnftables"
            value = "true"
          },
        ]
        securityContext = {
          capabilities = {
            add = [
              "NET_ADMIN",
              "NET_RAW",
            ]
          }
        }
      },
    ]
  }
}