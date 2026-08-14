resource "kubernetes_labels" "labels" {
  for_each = {
    for _, key in keys(lookup(local.members, "kubernetes-worker", {})) :
    key => merge(
      contains(keys(lookup(local.members, "kubernetes-master", {})), key) ? {
        "node-role.kubernetes.io/control-plane" = true
      } : {},
      contains(keys(lookup(local.members, "etcd", {})), key) ? {
        "node-role.kubernetes.io/etcd" = true
      } : {},
      contains(keys(lookup(local.members, "gateway", {})), key) ? {
        "node-role.kubernetes.io/gateway" = true
    } : {})
  }
  api_version = "v1"
  kind        = "Node"
  metadata {
    name = each.key
  }
  labels = each.value
  force  = true
}

# Bootstrap roles

resource "helm_release" "bootstrap" {
  chart            = "../helm-wrapper"
  name             = "bootstrap"
  namespace        = "kube-system"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({ manifests = [
      for _, m in [
        # https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/
        # enable bootstrapping nodes to create CSR
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRoleBinding"
          metadata = {
            name = "create-csrs-for-bootstrapping"
          }
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "ClusterRole"
            name     = "system:node-bootstrapper"
          }
          subjects = [
            {
              apiGroup = "rbac.authorization.k8s.io"
              kind     = "Group"
              name     = "system:bootstrappers"
            },
          ]
        },

        # Approve all CSRs for the group "system:bootstrappers"
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRoleBinding"
          metadata = {
            name = "auto-approve-csrs-for-group"
          }
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "ClusterRole"
            name     = "system:certificates.k8s.io:certificatesigningrequests:nodeclient"
          }
          subjects = [
            {
              apiGroup = "rbac.authorization.k8s.io"
              kind     = "Group"
              name     = "system:bootstrappers"
            },
          ]
        },

        # Approve renewal CSRs for the group "system:nodes"
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRoleBinding"
          metadata = {
            name = "auto-approve-renewals-for-nodes"
          }
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "ClusterRole"
            name     = "system:certificates.k8s.io:certificatesigningrequests:selfnodeclient"
          }
          subjects = [
            {
              apiGroup = "rbac.authorization.k8s.io"
              kind     = "Group"
              name     = "system:nodes"
            },
          ]
        },

        # kube apiserver access to kubelet #
        # https://stackoverflow.com/questions/48118125/kubernetes-rbac-role-verbs-to-exec-to-pod
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRole"
          metadata = {
            name = "system:kube-apiserver-to-kubelet"
            annotations = {
              "rbac.authorization.kubernetes.io/autoupdate" = "true"
            }
            labels = {
              "kubernetes.io/bootstrapping" = "rbac-defaults"
            }
          }
          rules = [
            {
              apiGroups = [""]
              resources = ["nodes/proxy", "nodes/stats", "nodes/log", "nodes/spec", "nodes/metrics"]
              verbs     = ["*"]
            },
            {
              apiGroups = [""]
              resources = ["pods", "pods/log"]
              verbs     = ["get", "list"]
            },
            {
              apiGroups = [""]
              resources = ["pods/exec"]
              verbs     = ["create"]
            },
          ]
        },
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRoleBinding"
          metadata = {
            name = "system:kube-apiserver"
          }
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "ClusterRole"
            name     = "system:kube-apiserver-to-kubelet"
          }
          subjects = [
            {
              apiGroup = "rbac.authorization.k8s.io"
              kind     = "User"
              name     = local.kubernetes.kubelet_client_user
            },
          ]
        },
      ] :
      yamlencode(m)
    ] }),
  ]
}

data "http" "cert-manager-crds-yaml" {
  url = join("", [
    "https://github.com/cert-manager/cert-manager/releases/download/v",
    trim(
      "1.21.1", # renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
      "v",
    ),
    "/cert-manager.crds.yaml",
  ])
  request_headers = {
    Accept = "application/yaml"
  }
}

resource "helm_release" "cert-manager-crds" {
  chart            = "../helm-wrapper"
  name             = "${local.services.cert-manager.name}-crds"
  namespace        = local.services.cert-manager.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      manifests = [
        data.http.cert-manager-crds-yaml.response_body,
      ]
    }),
  ]
}

# VictoriaMetrics is used, but keep this to allow many helm to deploy ServiceMonitor CRDs
resource "helm_release" "prometheus-crds" {
  name             = "prometheus-crds"
  namespace        = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-operator-crds"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "31.0.1"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
    }),
  ]
}