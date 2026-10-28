locals {
  c         = yamldecode(data.helm_template.local-path-provisioner.manifests["templates/configmap.yaml"])
  helperpod = yamldecode(local.c.data["helperPod.yaml"])

  helperpod_modded = yamlencode(merge(local.helperpod, {
    spec = merge(local.helperpod.spec, {
      # add SELinux security context to helperPod
      securityContext = {
        seLinuxOptions = {
          level = "s0-s0:c0.c1023"
        }
      }
    })
  }))
}

data "helm_template" "local-path-provisioner" {
  chart      = "local-path-provisioner"
  name       = var.name
  namespace  = var.namespace
  repository = "oci://ghcr.io/rancher/local-path-provisioner/charts"
  version    = "0.0.37" # renovate: datasource=docker depName=ghcr.io/rancher/local-path-provisioner/charts/local-path-provisioner depType=helm_regex
  values = [
    yamlencode({
      replicaCount = var.replicas
      storageClass = {
        create            = true
        name              = "local-path"
        provisionerName   = "rancher.io/local-path"
        defaultClass      = true
        defaultVolumeType = "local"
      }
      nodePathMap = [
        {
          node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = var.volume_paths
        },
      ]
      podDisruptionBudget = {
        enabled      = true
        minAvailable = 1
      }
      resources = {
        requests = {
          memory = "64Mi"
        }
        limits = {
          memory = "128Mi"
        }
      }
    }),
  ]
}

resource "helm_release" "wrapper" {
  chart            = "../helm-wrapper"
  name             = var.name
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  timeout          = var.timeout
  values = [
    yamlencode({
      manifests = values(merge(data.helm_template.local-path-provisioner.manifests, {
        "templates/configmap.yaml" = yamlencode(merge(local.c, {
          data = merge(local.c.data, {
            "helperPod.yaml" = local.helperpod_modded
          })
        }))
      }))
    }),
  ]
}