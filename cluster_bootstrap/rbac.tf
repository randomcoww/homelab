resource "helm_release" "rbac" {
  chart            = "../helm-wrapper"
  name             = "rbac"
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