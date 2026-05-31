# remaining kubernetes resources for flux operation

resource "helm_release" "fluxcd-bucket" {
  chart            = "../helm-wrapper"
  name             = "${local.endpoints.fluxcd.name}-bucket"
  namespace        = local.endpoints.fluxcd.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = [
        module.minio-user-secret-fluxcd.manifest,
        module.minio-tls.manifest,

        yamlencode({
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "Bucket"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket"
            annotations = {
              "checksum/minio-user-secret" = sha256(module.minio-user-secret-fluxcd.manifest)
              "checksum/tls"               = sha256(module.minio-tls.manifest)
            }
          }
          spec = {
            interval = "10s"
            provider = "generic"
            endpoint = data.terraform_remote_state.bootstrap.outputs.minio.endpoint
            secretRef = {
              name = module.minio-user-secret-fluxcd.name
            }
            bucketName = "fluxcd"
            certSecretRef = {
              name = module.minio-tls.name
            }
          }
        }),

        # resources that include CRD
        yamlencode({
          apiVersion = "kustomize.toolkit.fluxcd.io/v1"
          kind       = "Kustomization"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket-crd"
          }
          spec = {
            interval = "1m"
            sourceRef = {
              kind = "Bucket"
              name = "${local.endpoints.fluxcd.name}-bucket"
            }
            path    = "./crd"
            prune   = true
            wait    = true
            timeout = "5m"
          }
        }),

        # lower level services
        yamlencode({
          apiVersion = "kustomize.toolkit.fluxcd.io/v1"
          kind       = "Kustomization"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket-system"
          }
          spec = {
            interval = "1m"
            sourceRef = {
              kind = "Bucket"
              name = "${local.endpoints.fluxcd.name}-bucket"
            }
            dependsOn = [
              {
                name = "${local.endpoints.fluxcd.name}-bucket-crd"
              },
            ]
            path    = "./system"
            prune   = true
            wait    = true
            timeout = "5m"
          }
        }),

        # service
        yamlencode({
          apiVersion = "kustomize.toolkit.fluxcd.io/v1"
          kind       = "Kustomization"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket-service"
          }
          spec = {
            interval = "1m"
            sourceRef = {
              kind = "Bucket"
              name = "${local.endpoints.fluxcd.name}-bucket"
            }
            dependsOn = [
              {
                name = "${local.endpoints.fluxcd.name}-bucket-crd"
              },
            ]
            path    = "./service"
            prune   = true
            wait    = true
            timeout = "5m"
          }
        }),
      ]
    }),
  ]
}

# bucket ops resources

resource "minio_s3_object" "flux-crd" {
  for_each = merge({
    for name, manifests in local.flux_crd :
    "${name}.yaml" => join("---\n", manifests)
    }, {
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        for _, name in keys(local.flux_crd) :
        "${name}.yaml"
      ]
    })
  })

  bucket_name  = "fluxcd"
  object_name  = "crd/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.bucket["fluxcd"],
  ]
}

resource "minio_s3_object" "flux-system" {
  for_each = merge({
    for name, manifests in local.flux_system :
    "${name}.yaml" => join("---\n", manifests)
    }, {
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        for _, name in keys(local.flux_system) :
        "${name}.yaml"
      ]
    })
  })

  bucket_name  = "fluxcd"
  object_name  = "system/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.bucket["fluxcd"],
  ]
}

resource "minio_s3_object" "flux-service" {
  for_each = merge({
    for name, manifests in local.flux_service :
    "${name}.yaml" => join("---\n", manifests)
    }, {
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        for _, name in keys(local.flux_service) :
        "${name}.yaml"
      ]
    })
  })

  bucket_name  = "fluxcd"
  object_name  = "service/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.bucket["fluxcd"],
  ]
}