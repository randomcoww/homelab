locals {
  resource_claims = {
    amd-gpu-gfx1151 = "amd-gpu-gfx1151"
    amd-gpu-gfx90c  = "amd-gpu-gfx90c"
  }
}

resource "minio_s3_object" "fluxcd-resource-claims" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "resource.k8s.io/v1"
          kind       = "ResourceClaim"
          metadata = {
            name      = local.resource_claims.amd-gpu-gfx1151
            namespace = "default"
          }
          spec = {
            devices = {
              requests = [
                {
                  name = local.resource_claims.amd-gpu-gfx1151
                  exactly = {
                    deviceClassName = "gpu.amd.com"
                    selectors = [
                      {
                        cel = {
                          expression = <<-EOF
                          device.capacity["gpu.amd.com"].memory.isGreaterThan(quantity("60Gi"))
                          EOF
                        }
                      },
                    ]
                  }
                },
              ]
            }
          }
        },
        {
          apiVersion = "resource.k8s.io/v1"
          kind       = "ResourceClaimTemplate"
          metadata = {
            name      = local.resource_claims.amd-gpu-gfx90c
            namespace = "default"
          }
          spec = {
            spec = { # spec is repeated intentionally
              devices = {
                requests = [
                  {
                    name = local.resource_claims.amd-gpu-gfx90c
                    exactly = {
                      deviceClassName = "gpu.amd.com"
                      selectors = [
                        {
                          cel = {
                            expression = <<-EOF
                            device.attributes["gpu.amd.com"].deviceID == "0x15e7"
                            EOF
                          }
                        },
                      ]
                    }
                  }
                ]
              }
            }
          }
        },
      ] :
      yamlencode(m)
    ])
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "resource-claims/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}